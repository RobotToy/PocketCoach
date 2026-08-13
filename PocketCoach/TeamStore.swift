import Foundation
import SwiftUI
import UIKit

@MainActor
final class TeamStore: ObservableObject {
    @Published private(set) var team: Team
    private var persistEnabled = false

    init(team: Team? = nil) {
        if let team {
            self.team = team
        } else if let loaded = Self.loadFromDisk() {
            self.team = loaded
        } else {
            self.team = .sample()
        }
        persistEnabled = true
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = folder.appendingPathComponent("PocketCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("team.json")
    }

    private static func loadFromDisk() -> Team? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Team.self, from: data)
    }

    private func save() {
        guard persistEnabled else { return }
        do {
            let data = try JSONEncoder().encode(team)
            try data.write(to: Self.fileURL, options: [.atomic])
        } catch {
            print("PocketCoach save failed: \(error)")
        }
    }

    private func mutate(_ body: (inout Team) -> Void) {
        var copy = team
        body(&copy)
        team = copy
        save()
    }

    // MARK: - Lookups

    var activeLineup: Lineup {
        team.lineups.first(where: { $0.id == team.activeLineupId }) ?? team.lineups[0]
    }

    func player(id: UUID) -> Player? {
        team.players.first(where: { $0.id == id })
    }

    func savedLine(id: UUID) -> SavedLine? {
        team.savedLines.first(where: { $0.id == id })
    }

    func handlerPods(in _: Lineup? = nil) -> [PodId] {
        [.h1, .h2]
    }

    func cutterPods(in lineup: Lineup? = nil) -> [PodId] {
        let lineup = lineup ?? activeLineup
        return lineup.collapsedCutterPods ? [.c1, .c2] : [.c1, .c2, .c3]
    }

    func homePod(of playerId: UUID, in lineup: Lineup? = nil) -> PodId? {
        let lineup = lineup ?? activeLineup
        for pod in PodId.allCases where lineup.playerIds(in: pod).contains(playerId) {
            return pod
        }
        return nil
    }

    func benchPlayers(in lineup: Lineup? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        let assigned = Set(PodId.allCases.flatMap { lineup.playerIds(in: $0) })
        return team.players.filter { !assigned.contains($0.id) }
    }

    func players(in pod: PodId, lineup: Lineup? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        return lineup.playerIds(in: pod).compactMap { player(id: $0) }
    }

    func activePlayers(in pod: PodId, lineup: Lineup? = nil) -> [Player] {
        players(in: pod, lineup: lineup).filter { $0.status == .active }
    }

    func composedPod(_ pod: PodId, lineup: Lineup? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        var result = activePlayers(in: pod, lineup: lineup)
        let capacity = pod.capacity
        if result.count < capacity {
            let existing = Set(result.map(\.id))
            let floaters = team.players
                .filter {
                    $0.status == .active
                        && $0.floaterPodIds.contains(pod)
                        && !existing.contains($0.id)
                        && !(lineup.playerIds(in: pod).contains($0.id))
                }
                .sorted { $0.weekendPoints < $1.weekendPoints }
            for floater in floaters where result.count < capacity {
                result.append(floater)
            }
        }
        return result
    }

    func isCompatible(_ player: Player, with pod: PodId) -> Bool {
        if pod.isHandler {
            return player.role == .handler || player.role == .flex
        }
        return player.role == .cutter || player.role == .flex
    }

    func fillSuggestion(for pod: PodId) -> Player? {
        let current = composedPod(pod)
        guard current.count < pod.capacity else { return nil }
        let taken = Set(current.map(\.id))
        let bench = benchPlayers().filter { $0.status == .active && isCompatible($0, with: pod) && !taken.contains($0.id) }
        let fromOtherPods = team.players.filter { player in
            player.status == .active
                && isCompatible(player, with: pod)
                && !taken.contains(player.id)
                && homePod(of: player.id) != nil
                && homePod(of: player.id) != pod
        }
        let candidates = (bench + fromOtherPods).sorted { lhs, rhs in
            if lhs.weekendPoints != rhs.weekendPoints { return lhs.weekendPoints < rhs.weekendPoints }
            return lhs.name < rhs.name
        }
        return candidates.first
    }

    func shortPods() -> [PodId] {
        let rotating = handlerPods() + cutterPods()
        return rotating.filter { composedPod($0).count < $0.capacity }
    }

    // MARK: - Current line / rotation

    var currentHandlerPod: PodId {
        let pods = handlerPods()
        let index = team.game.hPointer % max(pods.count, 1)
        return pods[index]
    }

    var currentCutterPod: PodId {
        let pods = cutterPods()
        let index = team.game.cPointer % max(pods.count, 1)
        return pods[index]
    }

    func rotationLine(hIndex: Int? = nil, cIndex: Int? = nil) -> (handlers: [Player], cutters: [Player], hPod: PodId, cPod: PodId) {
        let hPods = handlerPods()
        let cPods = cutterPods()
        let hi = (hIndex ?? team.game.hPointer) % max(hPods.count, 1)
        let ci = (cIndex ?? team.game.cPointer) % max(cPods.count, 1)
        let hPod = hPods[hi]
        let cPod = cPods[ci]
        return (composedPod(hPod), composedPod(cPod), hPod, cPod)
    }

    func currentLinePlayers() -> [Player] {
        switch team.game.currentLineSource {
        case .rotation:
            let line = rotationLine()
            return line.handlers + line.cutters
        case .savedLine(let id):
            return composedSavedLine(id)
        }
    }

    func composedSavedLine(_ id: UUID) -> [Player] {
        guard let saved = savedLine(id: id) else { return [] }
        return saved.playerIds.compactMap { player(id: $0) }.filter { $0.status == .active }
    }

    func currentLineLabel() -> String {
        switch team.game.currentLineSource {
        case .rotation:
            let line = rotationLine()
            return "\(line.hPod.displayName) + \(line.cPod.displayName)"
        case .savedLine(let id):
            if let saved = savedLine(id: id) {
                return "\(saved.name) · \(saved.force.shortLabel)"
            }
            return "Saved line"
        }
    }

    var isSpecialLineActive: Bool {
        if case .savedLine = team.game.currentLineSource { return true }
        return false
    }

    func nextEvenPreviews(count: Int = 2) -> [(label: String, players: [Player])] {
        let startH = isSpecialLineActive ? team.game.hPointer : team.game.hPointer + 1
        let startC = isSpecialLineActive ? team.game.cPointer : team.game.cPointer + 1
        return (0..<count).map { offset in
            let line = rotationLine(hIndex: startH + offset, cIndex: startC + offset)
            return ("\(line.hPod.displayName)+\(line.cPod.displayName)", line.handlers + line.cutters)
        }
    }

    // MARK: - Wind suggestion

    func speedRank(_ speed: WindSpeed) -> Int {
        switch speed {
        case .calm: 0
        case .moderate: 1
        case .strong: 2
        }
    }

    func matchingWindRule() -> WindRule? {
        let wind = team.game.wind
        return team.windRules.first { rule in
            guard rule.gameType == wind.gameType else { return false }
            if let direction = rule.direction, direction != wind.direction { return false }
            if let minSpeed = rule.minSpeed, speedRank(wind.speed) < speedRank(minSpeed) { return false }
            if let upwind = rule.pointIsUpwind, upwind != wind.pointIsUpwind { return false }
            return true
        }
    }

    func suggestedDefense() -> (line: SavedLine, force: Force, ruleName: String)? {
        guard let rule = matchingWindRule(), let line = savedLine(id: rule.savedLineId) else { return nil }
        return (line, rule.forceOverride ?? line.force, rule.name)
    }

    // MARK: - Mutations: team / game

    func setTeamName(_ name: String) {
        mutate { $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.name : name }
    }

    func regenerateJoinCode() {
        mutate { $0.joinCode = Team.makeJoinCode() }
    }

    func updateWind(_ wind: WindState) {
        mutate { $0.game.wind = wind }
    }

    func togglePointIsUpwind() {
        mutate { $0.game.wind.pointIsUpwind.toggle() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func selectSavedLine(_ id: UUID) {
        mutate { $0.game.currentLineSource = .savedLine(id) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func clearToRotation() {
        mutate { $0.game.currentLineSource = .rotation }
    }

    func confirmPoint(weScored: Bool) {
        let onField = currentLinePlayers()
        let special = isSpecialLineActive
        let hPod = currentHandlerPod
        let cPod = currentCutterPod
        mutate { team in
            if weScored {
                team.game.usScore += 1
            } else {
                team.game.themScore += 1
            }
            let ids = Set(onField.map(\.id))
            for i in team.players.indices where ids.contains(team.players[i].id) {
                team.players[i].weekendPoints += 1
                team.players[i].gamePoints += 1
            }
            if special {
                team.game.specialPoints += 1
            } else {
                team.game.evenPoints += 1
                team.game.podOutings[hPod.rawValue, default: 0] += 1
                team.game.podOutings[cPod.rawValue, default: 0] += 1
                let hCount = 2
                let cCount = (team.lineups.first(where: { $0.id == team.activeLineupId })?.collapsedCutterPods == true) ? 2 : 3
                team.game.hPointer = (team.game.hPointer + 1) % hCount
                team.game.cPointer = (team.game.cPointer + 1) % max(cCount, 1)
            }
            if team.game.wind.gameType == .upwindDownwind {
                team.game.wind.pointIsUpwind.toggle()
            }
            team.game.currentLineSource = .rotation
            team.game.lastConfirmedAt = Date()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func bumpScore(us: Int = 0, them: Int = 0) {
        mutate {
            $0.game.usScore = max(0, $0.game.usScore + us)
            $0.game.themScore = max(0, $0.game.themScore + them)
        }
    }

    func startNewGame(lineupId: UUID, resetGamePoints: Bool) {
        mutate { team in
            team.activeLineupId = lineupId
            team.game.usScore = 0
            team.game.themScore = 0
            team.game.hPointer = 0
            team.game.cPointer = 0
            team.game.currentLineSource = .rotation
            team.game.specialPoints = 0
            team.game.evenPoints = 0
            team.game.podOutings = [:]
            team.game.lastConfirmedAt = nil
            if resetGamePoints {
                for i in team.players.indices {
                    team.players[i].gamePoints = 0
                }
            }
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func resetWeekendPoints() {
        mutate { team in
            for i in team.players.indices {
                team.players[i].weekendPoints = 0
                team.players[i].gamePoints = 0
            }
            team.game.evenPoints = 0
            team.game.specialPoints = 0
            team.game.podOutings = [:]
        }
    }

    func adjustPlayerPoints(id: UUID, weekendDelta: Int = 0, gameDelta: Int = 0) {
        mutate { team in
            guard let i = team.players.firstIndex(where: { $0.id == id }) else { return }
            team.players[i].weekendPoints = max(0, team.players[i].weekendPoints + weekendDelta)
            team.players[i].gamePoints = max(0, team.players[i].gamePoints + gameDelta)
        }
    }

    // MARK: - Lineups

    func setActiveLineup(_ id: UUID) {
        guard team.lineups.contains(where: { $0.id == id }) else { return }
        mutate {
            $0.activeLineupId = id
            $0.game.hPointer = 0
            $0.game.cPointer = 0
            $0.game.currentLineSource = .rotation
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func renameLineup(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == id }) else { return }
            team.lineups[i].name = trimmed
        }
    }

    func duplicateActiveLineup(named name: String? = nil) {
        let source = activeLineup
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let copy = Lineup(
            id: UUID(),
            name: trimmed.isEmpty ? "\(source.name) copy" : trimmed,
            pods: source.pods,
            collapsedCutterPods: source.collapsedCutterPods
        )
        mutate { $0.lineups.append(copy) }
    }

    func deleteLineup(_ id: UUID) {
        guard team.lineups.count > 1 else { return }
        mutate { team in
            team.lineups.removeAll { $0.id == id }
            if team.activeLineupId == id {
                team.activeLineupId = team.lineups[0].id
            }
        }
    }

    func setCollapsedCutterPods(_ collapsed: Bool) {
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == team.activeLineupId }) else { return }
            team.lineups[i].collapsedCutterPods = collapsed
            let cCount = collapsed ? 2 : 3
            team.game.cPointer = team.game.cPointer % cCount
        }
    }

    func assign(playerId: UUID, to pod: PodId?, in lineupId: UUID? = nil) {
        let lineupId = lineupId ?? team.activeLineupId
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == lineupId }) else { return }
            for key in PodId.allCases {
                team.lineups[i].pods[key] = (team.lineups[i].pods[key] ?? []).filter { $0 != playerId }
            }
            if let pod {
                var ids = team.lineups[i].pods[pod] ?? []
                if !ids.contains(playerId) { ids.append(playerId) }
                team.lineups[i].pods[pod] = ids
            }
        }
    }

    func applyFillSuggestion(for pod: PodId) {
        guard let suggestion = fillSuggestion(for: pod) else { return }
        assign(playerId: suggestion.id, to: pod)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Players

    func addPlayer(name: String, number: String?, role: PlayerRole) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let player = Player(name: trimmed, number: number.flatMap { $0.isEmpty ? nil : $0 }, role: role)
        mutate { $0.players.append(player) }
    }

    func updatePlayer(_ id: UUID, name: String, number: String?, role: PlayerRole, floaterPodIds: [PodId]) {
        mutate { team in
            guard let i = team.players.firstIndex(where: { $0.id == id }) else { return }
            team.players[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            team.players[i].number = number.flatMap { $0.isEmpty ? nil : $0 }
            team.players[i].role = role
            team.players[i].floaterPodIds = floaterPodIds
        }
    }

    func setStatus(_ id: UUID, _ status: PlayerStatus) {
        mutate { team in
            guard let i = team.players.firstIndex(where: { $0.id == id }) else { return }
            team.players[i].status = status
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func deletePlayer(_ id: UUID) {
        mutate { team in
            team.players.removeAll { $0.id == id }
            for i in team.lineups.indices {
                for pod in PodId.allCases {
                    team.lineups[i].pods[pod] = (team.lineups[i].pods[pod] ?? []).filter { $0 != id }
                }
            }
            for i in team.savedLines.indices {
                team.savedLines[i].playerIds.removeAll { $0 == id }
            }
        }
    }

    // MARK: - Saved lines & wind rules

    func upsertSavedLine(_ line: SavedLine) {
        mutate { team in
            if let i = team.savedLines.firstIndex(where: { $0.id == line.id }) {
                team.savedLines[i] = line
            } else {
                team.savedLines.append(line)
            }
        }
    }

    func deleteSavedLine(_ id: UUID) {
        mutate { team in
            team.savedLines.removeAll { $0.id == id }
            team.windRules.removeAll { $0.savedLineId == id }
            if case .savedLine(let current) = team.game.currentLineSource, current == id {
                team.game.currentLineSource = .rotation
            }
        }
    }

    func upsertWindRule(_ rule: WindRule) {
        mutate { team in
            if let i = team.windRules.firstIndex(where: { $0.id == rule.id }) {
                team.windRules[i] = rule
            } else {
                team.windRules.append(rule)
            }
        }
    }

    func deleteWindRule(_ id: UUID) {
        mutate { team in
            team.windRules.removeAll { $0.id == id }
        }
    }

    func restoreSampleData() {
        persistEnabled = false
        team = .sample()
        persistEnabled = true
        save()
    }
}
