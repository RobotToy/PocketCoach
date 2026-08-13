import SwiftUI

struct GameTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var showWind = false
    @State private var showNewGame = false
    @State private var showSettings = false
    @State private var playerForStatus: Player?

    var body: some View {
        NavigationStack {
            FieldScreen {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            header
                            scoreRow
                            windSection
                            suggestionBanner
                            fairnessWarning
                            shortPodWarnings
                            currentLineCard
                            nextLines
                            defenseButtons
                            podChips
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 120)
                    }
                    confirmBar
                }
            }
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Team settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New game") { showNewGame = true }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .sheet(isPresented: $showWind) { WindSheet() }
            .sheet(isPresented: $showNewGame) { NewGameSheet() }
            .sheet(isPresented: $showSettings) { TeamSettingsSheet() }
            .sheet(item: $playerForStatus) { player in
                PlayerStatusSheet(player: player)
            }
        }
    }

    private var header: some View {
        HStack {
            LineupMenu(store: store)
            Spacer()
            if store.isSpecialLineActive {
                Button("Back to even") {
                    store.clearToRotation()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FieldTheme.warn)
            }
        }
    }

    private var scoreRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ScoreBox(title: "Us", value: store.team.game.usScore) {
                    store.bumpScore(us: -1)
                } onPlus: {
                    store.bumpScore(us: 1)
                }
                ScoreBox(title: "Them", value: store.team.game.themScore) {
                    store.bumpScore(them: -1)
                } onPlus: {
                    store.bumpScore(them: 1)
                }
            }
            Text("+/− fixes the score only. We scored / They scored also counts play time.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
        }
    }

    private var windSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showWind = true } label: {
                HStack {
                    Image(systemName: "wind")
                    Text(windSummary)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(FieldTheme.textPrimary)
                .padding(14)
                .frame(minHeight: 52)
                .background(FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if store.team.game.wind.gameType == .upwindDownwind {
                Button {
                    store.togglePointIsUpwind()
                } label: {
                    Text(store.team.game.wind.pointIsUpwind ? "This point: defending UPWIND (they attack into wind)" : "This point: defending DOWNWIND (they attack with wind)")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(FieldButtonStyle(fill: FieldTheme.accent.opacity(0.22), minHeight: 52))
            }
        }
    }

    private var windSummary: String {
        let wind = store.team.game.wind
        switch wind.gameType {
        case .none:
            return "No wind · \(wind.speed.displayName) · tap to edit"
        case .crosswind:
            return "Crosswind \(wind.direction.displayName) · \(wind.speed.displayName)"
        case .upwindDownwind:
            return "Up/downwind · \(wind.speed.displayName)"
        }
    }

    @ViewBuilder
    private var suggestionBanner: some View {
        if let suggestion = store.suggestedDefense() {
            Button {
                store.selectSavedLine(suggestion.line.id)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested D")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FieldTheme.accent)
                    Text("\(suggestion.line.name) · force \(suggestion.force.displayName)")
                        .font(.headline)
                    Text(suggestion.ruleName)
                        .font(.caption)
                        .foregroundStyle(FieldTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(FieldTheme.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FieldTheme.accent.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var fairnessWarning: some View {
        if store.team.game.totalPoints >= 4, store.team.game.specialRatio > 0.25 {
            InlineWarning(
                text: String(format: "Kill/zone usage is %.0f%% of points — target is ~20%%.", store.team.game.specialRatio * 100),
                tone: FieldTheme.warn
            )
        }
    }

    @ViewBuilder
    private var shortPodWarnings: some View {
        let shorts = store.shortPods()
        if !shorts.isEmpty, !store.isSpecialLineActive {
            InlineWarning(
                text: "Short pods: \(shorts.map(\.displayName).joined(separator: ", ")). Fill on Roster or tap a suggestion.",
                tone: FieldTheme.danger
            )
        }
    }

    private var currentLineCard: some View {
        let players = store.currentLinePlayers()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("On now")
                    .font(.headline)
                Spacer()
                Text(store.currentLineLabel())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(store.isSpecialLineActive ? FieldTheme.warn : FieldTheme.score)
            }
            if players.isEmpty {
                Text("No active players on this line. Check injuries or pod assignments.")
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                ForEach(players) { player in
                    Button { playerForStatus = player } label: {
                        PlayerChip(player: player, showsPoints: true)
                    }
                    .buttonStyle(.plain)
                }
                Text("Tap a player to mark injured / out.")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
            if store.isSpecialLineActive, let id = savedId, let saved = store.savedLine(id: id) {
                let missing = saved.playerIds.compactMap { store.player(id: $0) }.filter { $0.status != .active }
                if !missing.isEmpty {
                    InlineWarning(text: "Missing: \(missing.map(\.name).joined(separator: ", ")).", tone: FieldTheme.danger)
                }
            }
        }
        .padding(14)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var savedId: UUID? {
        if case .savedLine(let id) = store.team.game.currentLineSource { return id }
        return nil
    }

    private var nextLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.isSpecialLineActive ? "Even rotation resumes with" : "Next even lines")
                .font(.headline)
            ForEach(Array(store.nextEvenPreviews().enumerated()), id: \.offset) { _, preview in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(FieldTheme.accent)
                    Text(preview.players.map(\.name).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(FieldTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var defenseButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zone / kill interrupt")
                .font(.headline)
            Text("Counts play time, does not skip the next even pods.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(store.team.savedLines) { line in
                    Button {
                        store.selectSavedLine(line.id)
                    } label: {
                        VStack(spacing: 4) {
                            Text(line.name)
                                .font(.headline)
                            Text(line.force.shortLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FieldTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(
                        FieldButtonStyle(
                            fill: store.savedIdIsCurrent(line.id) ? FieldTheme.warn.opacity(0.25) : FieldTheme.surfaceRaised,
                            minHeight: 64
                        )
                    )
                }
            }
        }
    }

    private var podChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pod time")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.handlerPods() + store.cutterPods()) { pod in
                        VStack(spacing: 4) {
                            Text(pod.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                            Text("\(store.team.game.outings(for: pod))")
                                .font(.title2.weight(.bold).monospacedDigit())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(FieldTheme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var confirmBar: some View {
        HStack(spacing: 12) {
            Button {
                store.confirmPoint(weScored: true)
            } label: {
                Text("We scored")
            }
            .buttonStyle(FieldButtonStyle(fill: FieldTheme.score.opacity(0.28), foreground: FieldTheme.score, minHeight: 64))

            Button {
                store.confirmPoint(weScored: false)
            } label: {
                Text("They scored")
            }
            .buttonStyle(FieldButtonStyle(fill: FieldTheme.danger.opacity(0.22), foreground: FieldTheme.danger, minHeight: 64))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(FieldTheme.background.opacity(0.96))
    }
}

private extension TeamStore {
    func savedIdIsCurrent(_ id: UUID) -> Bool {
        if case .savedLine(let current) = team.game.currentLineSource { return current == id }
        return false
    }
}
