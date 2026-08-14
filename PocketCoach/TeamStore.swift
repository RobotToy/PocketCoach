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
        migrateNoWindDefaultIfNeeded()
    }

    /// Old sample data forced backhand in no wind. Product default is flick, no unders.
    private func migrateNoWindDefaultIfNeeded() {
        let oldName = "No / light wind → Person"
        let newName = "No wind → Person · Flick · no unders"
        let needsRule = team.windRules.contains {
            $0.gameType == .none
                && $0.savedLineId == SeedIDs.person
                && ($0.forceOverride == .backhand || $0.name == oldName)
        }
        let needsPerson = team.savedLines.contains { $0.id == SeedIDs.person && $0.force == .backhand }
        guard needsRule || needsPerson else { return }
        mutate { team in
            for i in team.windRules.indices
            where team.windRules[i].gameType == .none && team.windRules[i].savedLineId == SeedIDs.person {
                if team.windRules[i].forceOverride == .backhand {
                    team.windRules[i].forceOverride = .flickNoUnders
                }
                if team.windRules[i].name == oldName {
                    team.windRules[i].name = newName
                }
            }
            if let i = team.savedLines.firstIndex(where: { $0.id == SeedIDs.person && $0.force == .backhand }) {
                team.savedLines[i].force = .flickNoUnders
            }
        }
    }

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

    private func mutateGame(_ body: (inout GameSession) -> Void) {
        mutate { team in
            guard let i = team.games.firstIndex(where: { $0.id == team.activeGameId }) else { return }
            body(&team.games[i])
        }
    }

    // MARK: - Lookups

    var activeGame: GameSession {
        team.games.first(where: { $0.id == team.activeGameId }) ?? team.games[0]
    }

    var activeLineup: Lineup {
        if let fromGame = team.lineups.first(where: { $0.id == activeGame.lineupId }) {
            return fromGame
        }
        return team.lineups.first(where: { $0.id == team.activeLineupId }) ?? team.lineups[0]
    }

    func player(id: UUID) -> Player? {
        team.players.first(where: { $0.id == id })
    }

    func savedLine(id: UUID) -> SavedLine? {
        team.savedLines.first(where: { $0.id == id })
    }

    func customLine(id: UUID) -> CustomLine? {
        activeGame.customLines.first(where: { $0.id == id })
    }

    func handlerPods() -> [PodId] { [.h1, .h2] }
    func cutterPods() -> [PodId] { [.c1, .c2, .c3] }

    func homePod(of playerId: UUID, in lineup: Lineup? = nil) -> PodId? {
        let lineup = lineup ?? activeLineup
        for pod in PodId.allCases where lineup.playerIds(in: pod).contains(playerId) {
            return pod
        }
        return nil
    }

    func players(in pod: PodId, lineup: Lineup? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        return lineup.playerIds(in: pod).compactMap { player(id: $0) }
    }

    func activeMembers(in pod: PodId, lineup: Lineup? = nil) -> [Player] {
        players(in: pod, lineup: lineup).filter { $0.status == .active }
    }

    func sidelinePlayers() -> [Player] {
        team.players.filter { $0.status.isSideline }
            .sorted { $0.name < $1.name }
    }

    func unassignedActivePlayers(in lineup: Lineup? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        let assigned = Set(PodId.allCases.flatMap { lineup.playerIds(in: $0) })
        return team.players.filter { $0.status == .active && !assigned.contains($0.id) }
    }

    func isCompatible(_ player: Player, with pod: PodId) -> Bool {
        if pod.isHandler {
            return player.role == .handler || player.role == .flex
        }
        return player.role == .cutter || player.role == .flex
    }

    /// Compose a pod using home members + rotating fillers when short.
    func composedPod(_ pod: PodId, lineup: Lineup? = nil, fillPointers: [String: Int]? = nil) -> [Player] {
        let lineup = lineup ?? activeLineup
        var result = activeMembers(in: pod, lineup: lineup)
        let capacity = pod.capacity
        guard result.count < capacity else { return result }

        let existing = Set(result.map(\.id))
        let fillers = lineup.fillers(for: pod)
            .compactMap { player(id: $0) }
            .filter { $0.status == .active && !existing.contains($0.id) && isCompatible($0, with: pod) }

        guard !fillers.isEmpty else {
            // Fallback: least-played compatible from other pods
            let pointers = fillPointers ?? activeGame.fillPointers
            _ = pointers
            let extras = team.players
                .filter {
                    $0.status == .active
                        && !existing.contains($0.id)
                        && isCompatible($0, with: pod)
                        && homePod(of: $0.id, in: lineup) != pod
                }
                .sorted { points(for: $0.id, scope: .weekend) < points(for: $1.id, scope: .weekend) }
            for extra in extras where result.count < capacity {
                result.append(extra)
            }
            return result
        }

        let key = pod.rawValue
        let start = (fillPointers ?? activeGame.fillPointers)[key] ?? lineup.fillPointers[pod] ?? 0
        var idx = start % fillers.count
        var added = 0
        while result.count < capacity && added < fillers.count {
            let candidate = fillers[idx % fillers.count]
            if !result.contains(where: { $0.id == candidate.id }) {
                result.append(candidate)
            }
            idx += 1
            added += 1
        }
        return result
    }

    func shortPods() -> [PodId] {
        (handlerPods() + cutterPods()).filter { composedPod($0).count < $0.capacity }
    }

    func fillSuggestions() -> [(pod: PodId, player: Player, reason: String)] {
        shortPods().compactMap { pod in
            let current = Set(composedPod(pod).map(\.id))
            let fromFill = activeLineup.fillers(for: pod)
                .compactMap { player(id: $0) }
                .first { $0.status == .active && !current.contains($0.id) }
            if let fromFill {
                return (pod, fromFill, "Next on \(pod.displayName) fill list")
            }
            let fallback = team.players
                .filter {
                    $0.status == .active
                        && isCompatible($0, with: pod)
                        && !current.contains($0.id)
                        && homePod(of: $0.id) != pod
                }
                .sorted { points(for: $0.id, scope: .weekend) < points(for: $1.id, scope: .weekend) }
                .first
            guard let fallback else { return nil }
            return (pod, fallback, "Least played compatible")
        }
    }

    // MARK: - Points scopes

    func games(in scope: TimeScope, gameId: UUID? = nil) -> [GameSession] {
        switch scope {
        case .game:
            let id = gameId ?? team.activeGameId
            return team.games.filter { $0.id == id }
        case .day:
            let key = activeGame.dayKey
            return team.games.filter { $0.dayKey == key }
        case .weekend:
            return team.games
        }
    }

    func points(for playerId: UUID, scope: TimeScope, gameId: UUID? = nil) -> Int {
        games(in: scope, gameId: gameId).reduce(0) { $0 + $1.points(for: playerId) }
    }

    func specialRatio(scope: TimeScope, gameId: UUID? = nil) -> (even: Int, special: Int, ratio: Double) {
        let gs = games(in: scope, gameId: gameId)
        let even = gs.reduce(0) { $0 + $1.evenPoints }
        let special = gs.reduce(0) { $0 + $1.specialPoints }
        let total = even + special
        let ratio = total == 0 ? 0 : Double(special) / Double(total)
        return (even, special, ratio)
    }

    func podOutings(_ pod: PodId, scope: TimeScope, gameId: UUID? = nil) -> Int {
        games(in: scope, gameId: gameId).reduce(0) { $0 + $1.outings(for: pod) }
    }

    // MARK: - Current line

    var currentHandlerPod: PodId {
        let pods = handlerPods()
        return pods[activeGame.hPointer % pods.count]
    }

    var currentCutterPod: PodId {
        let pods = cutterPods()
        return pods[activeGame.cPointer % pods.count]
    }

    func rotationLine(hIndex: Int? = nil, cIndex: Int? = nil) -> (handlers: [Player], cutters: [Player], hPod: PodId, cPod: PodId) {
        let hPods = handlerPods()
        let cPods = cutterPods()
        let hi = (hIndex ?? activeGame.hPointer) % hPods.count
        let ci = (cIndex ?? activeGame.cPointer) % cPods.count
        let hPod = hPods[hi]
        let cPod = cPods[ci]
        return (composedPod(hPod), composedPod(cPod), hPod, cPod)
    }

    func currentLinePlayers() -> [Player] {
        if let override = activeGame.onNowOverride {
            return override.compactMap { player(id: $0) }
        }
        switch activeGame.currentLineSource {
        case .rotation:
            let line = rotationLine()
            return line.handlers + line.cutters
        case .savedLine(let id):
            return composedSavedLine(id)
        case .custom(let id):
            return customLine(id: id)?.playerIds.compactMap { player(id: $0) }.filter { $0.status == .active } ?? []
        case .manual:
            return []
        }
    }

    func composedSavedLine(_ id: UUID) -> [Player] {
        guard let saved = savedLine(id: id) else { return [] }
        return saved.playerIds.compactMap { player(id: $0) }.filter { $0.status == .active }
    }

    func currentLineLabel() -> String {
        if activeGame.onNowOverride != nil { return "Custom on-field" }
        switch activeGame.currentLineSource {
        case .rotation:
            let line = rotationLine()
            return "\(line.hPod.displayName) + \(line.cPod.displayName)"
        case .savedLine(let id):
            if let saved = savedLine(id: id) {
                return "\(saved.name) · \(saved.force.shortLabel)"
            }
            return "Zone line"
        case .custom(let id):
            return customLine(id: id)?.name ?? "Custom"
        case .manual:
            return "Manual"
        }
    }

    var isSpecialLineActive: Bool {
        if activeGame.onNowOverride != nil { return true }
        switch activeGame.currentLineSource {
        case .savedLine, .custom, .manual: return true
        case .rotation: return false
        }
    }

    func resolveNextCard(_ card: NextLineCard) -> (title: String, subtitle: String, players: [Player], force: Force?) {
        switch card.kind {
        case .even:
            let line = rotationLine(
                hIndex: activeGame.hPointer + card.evenOffset,
                cIndex: activeGame.cPointer + card.evenOffset
            )
            let names = (line.handlers + line.cutters).map(\.name).joined(separator: " · ")
            return ("\(line.hPod.displayName)+\(line.cPod.displayName)", names, line.handlers + line.cutters, nil)
        case .zone:
            guard let id = card.relatedId, let saved = savedLine(id: id) else {
                return ("Zone", "Missing line", [], nil)
            }
            let players = composedSavedLine(id)
            return (saved.name, "Force \(saved.force.displayName) · \(players.map(\.name).joined(separator: " · "))", players, saved.force)
        case .custom:
            guard let id = card.relatedId, let custom = customLine(id: id) else {
                return ("Custom", "Missing", [], nil)
            }
            let players = custom.playerIds.compactMap { player(id: $0) }
            return (custom.name, players.map(\.name).joined(separator: " · "), players, nil)
        }
    }

    // MARK: - Wind

    func speedRank(_ speed: WindSpeed) -> Int {
        switch speed {
        case .calm: 0
        case .moderate: 1
        case .strong: 2
        }
    }

    func matchingWindRule() -> WindRule? {
        let wind = activeGame.wind
        return team.windRules.first { rule in
            guard rule.gameType == wind.gameType else { return false }
            if let direction = rule.direction, direction != wind.direction { return false }
            if let minSpeed = rule.minSpeed, speedRank(wind.speed) < speedRank(minSpeed) { return false }
            if let upwind = rule.pointIsUpwind, upwind != wind.pointIsUpwind { return false }
            return true
        }
    }

    func suggestedDefense() -> (line: SavedLine, force: Force, ruleName: String)? {
        let wind = activeGame.wind
        if wind.gameType == .none {
            if let rule = matchingWindRule(), let line = savedLine(id: rule.savedLineId) {
                return (line, .flickNoUnders, rule.name)
            }
            if let person = team.savedLines.first(where: { $0.defenseKind == .person }) {
                return (person, .flickNoUnders, "No wind · force flick, no unders")
            }
            return nil
        }
        guard let rule = matchingWindRule(), let line = savedLine(id: rule.savedLineId) else { return nil }
        return (line, rule.forceOverride ?? line.force, rule.name)
    }

    // MARK: - Games

    func setActiveGame(_ id: UUID) {
        guard team.games.contains(where: { $0.id == id }) else { return }
        mutate {
            $0.activeGameId = id
            if let g = $0.games.first(where: { $0.id == id }) {
                $0.activeLineupId = g.lineupId
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func createGame(named name: String?, lineupId: UUID?) {
        let nextIndex = team.games.count + 1
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = trimmed.isEmpty ? "Game \(nextIndex)" : trimmed
        let lid = lineupId ?? team.activeLineupId
        let wind = activeGame.wind
        var session = GameSession.fresh(name: label, lineupId: lid, wind: wind)
        // Seed next cards with even + all zone lines
        var cards = GameSession.defaultNextCards()
        for line in team.savedLines {
            cards.append(NextLineCard(kind: .zone, relatedId: line.id))
        }
        session.nextLineCards = cards
        mutate {
            $0.games.append(session)
            $0.activeGameId = session.id
            $0.activeLineupId = lid
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func renameGame(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { team in
            guard let i = team.games.firstIndex(where: { $0.id == id }) else { return }
            team.games[i].name = trimmed
        }
    }

    func resetGame(_ id: UUID) {
        mutate { team in
            guard let i = team.games.firstIndex(where: { $0.id == id }) else { return }
            team.games[i].usScore = 0
            team.games[i].themScore = 0
            team.games[i].clearPlayTime()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func deleteGame(_ id: UUID) {
        guard team.games.count > 1, team.games.contains(where: { $0.id == id }) else { return }
        mutate { team in
            team.games.removeAll { $0.id == id }
            if team.activeGameId == id {
                let next = team.games.sorted { $0.createdAt > $1.createdAt }[0]
                team.activeGameId = next.id
                team.activeLineupId = next.lineupId
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func updateTournament(_ settings: TournamentSettings) {
        mutate { $0.tournament = settings }
    }

    func setFlipPreference(_ pref: FlipPreference, notes: String) {
        mutate {
            $0.flipPreference = pref
            $0.flipNotes = notes
        }
    }

    func setTeamName(_ name: String) {
        mutate { $0.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.name : name }
    }

    func regenerateJoinCode() {
        mutate { $0.joinCode = Team.makeJoinCode() }
    }

    func updateWind(_ wind: WindState) {
        mutateGame { $0.wind = wind }
    }

    func togglePointIsUpwind() {
        mutateGame { $0.wind.pointIsUpwind.toggle() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func selectSavedLine(_ id: UUID) {
        mutateGame {
            $0.currentLineSource = .savedLine(id)
            $0.onNowOverride = nil
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func selectCustomLine(_ id: UUID) {
        mutateGame {
            $0.currentLineSource = .custom(id)
            $0.onNowOverride = nil
        }
    }

    func selectNextCard(_ card: NextLineCard) {
        switch card.kind {
        case .even:
            mutateGame {
                $0.hPointer = ($0.hPointer + card.evenOffset) % 2
                $0.cPointer = ($0.cPointer + card.evenOffset) % 3
                $0.currentLineSource = .rotation
                $0.onNowOverride = nil
            }
        case .zone:
            if let id = card.relatedId { selectSavedLine(id) }
        case .custom:
            if let id = card.relatedId { selectCustomLine(id) }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func clearToRotation() {
        mutateGame {
            $0.currentLineSource = .rotation
            $0.onNowOverride = nil
        }
    }

    func setOnNowPlayers(_ ids: [UUID]) {
        mutateGame {
            $0.onNowOverride = ids
            $0.currentLineSource = .manual
        }
    }

    func removeFromOnNow(_ id: UUID) {
        var current = currentLinePlayers().map(\.id)
        current.removeAll { $0 == id }
        setOnNowPlayers(current)
    }

    func addToOnNow(_ id: UUID) {
        var current = currentLinePlayers().map(\.id)
        guard !current.contains(id) else { return }
        current.append(id)
        setOnNowPlayers(current)
    }

    func moveNextCards(from source: IndexSet, to destination: Int) {
        mutateGame { game in
            game.nextLineCards.move(fromOffsets: source, toOffset: destination)
        }
    }

    func reorderNextCards(_ cards: [NextLineCard]) {
        mutateGame { $0.nextLineCards = cards }
    }

    func addCustomLine(name: String, playerIds: [UUID]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let line = CustomLine(name: trimmed.isEmpty ? "Custom" : trimmed, playerIds: playerIds)
        mutateGame { game in
            game.customLines.append(line)
            game.nextLineCards.append(NextLineCard(kind: .custom, relatedId: line.id))
        }
    }

    func confirmPoint(weScored: Bool) {
        let onField = currentLinePlayers()
        let special = isSpecialLineActive
        let hPod = currentHandlerPod
        let cPod = currentCutterPod
        let shortBefore = shortPods()
        mutate { team in
            guard let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) else { return }
            if weScored {
                team.games[gi].usScore += 1
            } else {
                team.games[gi].themScore += 1
            }
            for player in onField {
                let key = player.id.uuidString
                team.games[gi].playerPoints[key, default: 0] += 1
            }
            if special {
                team.games[gi].specialPoints += 1
            } else {
                team.games[gi].evenPoints += 1
                team.games[gi].podOutings[hPod.rawValue, default: 0] += 1
                team.games[gi].podOutings[cPod.rawValue, default: 0] += 1
                // Advance fill pointers for short pods that used fillers
                for pod in [hPod, cPod] {
                    if let li = team.lineups.firstIndex(where: { $0.id == team.games[gi].lineupId }) {
                        let homeActive = team.lineups[li].playerIds(in: pod)
                            .compactMap { pid in team.players.first(where: { $0.id == pid && $0.status == .active }) }
                        if homeActive.count < pod.capacity {
                            let fillers = team.lineups[li].fillers(for: pod)
                            if !fillers.isEmpty {
                                let key = pod.rawValue
                                let cur = team.games[gi].fillPointers[key] ?? 0
                                team.games[gi].fillPointers[key] = cur + (pod.capacity - homeActive.count)
                            }
                        }
                    }
                }
                team.games[gi].hPointer = (team.games[gi].hPointer + 1) % 2
                team.games[gi].cPointer = (team.games[gi].cPointer + 1) % 3
            }
            if team.games[gi].wind.gameType == .upwindDownwind {
                team.games[gi].wind.pointIsUpwind.toggle()
            }
            team.games[gi].currentLineSource = .rotation
            team.games[gi].onNowOverride = nil
            team.games[gi].lastConfirmedAt = Date()
            _ = shortBefore
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func bumpScore(us: Int = 0, them: Int = 0) {
        mutateGame {
            $0.usScore = max(0, $0.usScore + us)
            $0.themScore = max(0, $0.themScore + them)
        }
    }

    func adjustPlayerPoints(id: UUID, delta: Int, scope: TimeScope) {
        mutate { team in
            switch scope {
            case .game:
                guard let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) else { return }
                let key = id.uuidString
                team.games[gi].playerPoints[key] = max(0, (team.games[gi].playerPoints[key] ?? 0) + delta)
            case .day, .weekend:
                // Apply to active game so totals move immediately
                guard let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) else { return }
                let key = id.uuidString
                team.games[gi].playerPoints[key] = max(0, (team.games[gi].playerPoints[key] ?? 0) + delta)
            }
        }
    }

    // MARK: - Lineups

    func setActiveLineup(_ id: UUID) {
        guard team.lineups.contains(where: { $0.id == id }) else { return }
        mutate { team in
            team.activeLineupId = id
            if let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) {
                team.games[gi].lineupId = id
                team.games[gi].hPointer = 0
                team.games[gi].cPointer = 0
                team.games[gi].currentLineSource = .rotation
                team.games[gi].onNowOverride = nil
            }
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
            fillRotation: source.fillRotation,
            fillPointers: [:]
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

    func archiveCurrentLineup(note: String? = nil) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = trimmed.isEmpty
            ? "\(activeLineup.name) · \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
            : trimmed
        let snap = LineupSnapshot(name: label, lineup: activeLineup)
        mutate { $0.lineupHistory.insert(snap, at: 0) }
    }

    func restoreSnapshot(_ id: UUID) {
        guard let snap = team.lineupHistory.first(where: { $0.id == id }) else { return }
        archiveCurrentLineup(note: "Before restore")
        var restored = snap.lineup
        restored.id = UUID()
        restored.name = "\(snap.lineup.name) restored"
        mutate {
            $0.lineups.append(restored)
            $0.activeLineupId = restored.id
        }
    }

    func replaceActiveLineupPods(_ pods: [PodId: [UUID]], fillRotation: [PodId: [UUID]]) {
        archiveCurrentLineup()
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == team.activeLineupId }) else { return }
            team.lineups[i].pods = pods
            team.lineups[i].fillRotation = fillRotation
            team.lineups[i].fillPointers = [:]
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

    func setFillRotation(for pod: PodId, playerIds: [UUID]) {
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == team.activeLineupId }) else { return }
            team.lineups[i].fillRotation[pod] = playerIds
        }
    }

    func addToFillRotation(playerId: UUID, pod: PodId) {
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == team.activeLineupId }) else { return }
            var list = team.lineups[i].fillRotation[pod] ?? []
            if !list.contains(playerId) { list.append(playerId) }
            team.lineups[i].fillRotation[pod] = list
        }
    }

    func removeFromFillRotation(playerId: UUID, pod: PodId) {
        mutate { team in
            guard let i = team.lineups.firstIndex(where: { $0.id == team.activeLineupId }) else { return }
            team.lineups[i].fillRotation[pod] = (team.lineups[i].fillRotation[pod] ?? []).filter { $0 != playerId }
        }
    }

    func applyFillSuggestion(pod: PodId, playerId: UUID) {
        addToFillRotation(playerId: playerId, pod: pod)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Players

    func addPlayer(name: String, number: String?, role: PlayerRole) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { $0.players.append(Player(name: trimmed, number: number.flatMap { $0.isEmpty ? nil : $0 }, role: role)) }
    }

    func updatePlayer(_ id: UUID, name: String, number: String?, role: PlayerRole) {
        mutate { team in
            guard let i = team.players.firstIndex(where: { $0.id == id }) else { return }
            team.players[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            team.players[i].number = number.flatMap { $0.isEmpty ? nil : $0 }
            team.players[i].role = role
        }
    }

    func setStatus(_ id: UUID, _ status: PlayerStatus) {
        mutate { team in
            guard let i = team.players.firstIndex(where: { $0.id == id }) else { return }
            team.players[i].status = status
            // Drop injured/out from on-now override
            if status.isSideline, let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) {
                team.games[gi].onNowOverride = team.games[gi].onNowOverride?.filter { $0 != id }
            }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func deletePlayer(_ id: UUID) {
        mutate { team in
            team.players.removeAll { $0.id == id }
            for i in team.lineups.indices {
                for pod in PodId.allCases {
                    team.lineups[i].pods[pod] = (team.lineups[i].pods[pod] ?? []).filter { $0 != id }
                    team.lineups[i].fillRotation[pod] = (team.lineups[i].fillRotation[pod] ?? []).filter { $0 != id }
                }
            }
            for i in team.savedLines.indices {
                team.savedLines[i].playerIds.removeAll { $0 == id }
            }
        }
    }

    // MARK: - Saved lines / wind

    func upsertSavedLine(_ line: SavedLine) {
        mutate { team in
            if let i = team.savedLines.firstIndex(where: { $0.id == line.id }) {
                team.savedLines[i] = line
            } else {
                team.savedLines.append(line)
                // Add to next-line cards of active game
                if let gi = team.games.firstIndex(where: { $0.id == team.activeGameId }) {
                    team.games[gi].nextLineCards.append(NextLineCard(kind: .zone, relatedId: line.id))
                }
            }
        }
    }

    func deleteSavedLine(_ id: UUID) {
        mutate { team in
            team.savedLines.removeAll { $0.id == id }
            team.windRules.removeAll { $0.savedLineId == id }
            for i in team.games.indices {
                team.games[i].nextLineCards.removeAll { $0.kind == .zone && $0.relatedId == id }
                if case .savedLine(let current) = team.games[i].currentLineSource, current == id {
                    team.games[i].currentLineSource = .rotation
                }
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
        mutate { $0.windRules.removeAll { $0.id == id } }
    }

    func resetAllPlayTime() {
        mutate { team in
            for i in team.games.indices {
                team.games[i].clearPlayTime()
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func restoreSampleData() {
        persistEnabled = false
        team = .sample()
        persistEnabled = true
        save()
    }
}
