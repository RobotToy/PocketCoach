import SwiftUI
import UniformTypeIdentifiers

struct GameTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var showWind = false
    @State private var showSettings = false
    @State private var showCaps = false
    @State private var showEditOnNow = false
    @State private var showCustomLine = false
    @State private var playerForStatus: Player?
    @State private var draggingCard: NextLineCard?

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
                            fillSuggestions
                            currentLineCard
                            nextLinesSection
                            capsFooter
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
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.createGame(named: nil, lineupId: nil)
                    } label: {
                        Label("New game", systemImage: "plus")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .sheet(isPresented: $showWind) { WindSheet() }
            .sheet(isPresented: $showSettings) { TeamSettingsSheet() }
            .sheet(isPresented: $showCaps) { TournamentCapsSheet() }
            .sheet(isPresented: $showEditOnNow) { EditOnNowSheet() }
            .sheet(isPresented: $showCustomLine) { CustomLineSheet() }
            .sheet(item: $playerForStatus) { PlayerStatusSheet(player: $0) }
        }
    }

    private var header: some View {
        HStack {
            GameMenu(store: store)
            Spacer()
            if store.isSpecialLineActive {
                Button("Back to even") { store.clearToRotation() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FieldTheme.warn)
            }
        }
    }

    private var scoreRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ScoreBox(title: "Us", value: store.activeGame.usScore, goal: store.team.tournament.gameTo) {
                    store.bumpScore(us: -1)
                } onPlus: {
                    store.bumpScore(us: 1)
                }
                ScoreBox(title: "Them", value: store.activeGame.themScore, goal: store.team.tournament.gameTo) {
                    store.bumpScore(them: -1)
                } onPlus: {
                    store.bumpScore(them: 1)
                }
            }
            Text("+/− fixes score only. We scored / They scored also counts play time.")
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

            if store.activeGame.wind.gameType == .upwindDownwind {
                Button { store.togglePointIsUpwind() } label: {
                    Text(store.activeGame.wind.pointIsUpwind
                         ? "This point: defending UPWIND"
                         : "This point: defending DOWNWIND")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(FieldButtonStyle(fill: FieldTheme.accent.opacity(0.22), minHeight: 52))
            }
        }
    }

    private var windSummary: String {
        let wind = store.activeGame.wind
        switch wind.gameType {
        case .none: return "No wind · \(wind.speed.displayName)"
        case .crosswind: return "Crosswind \(wind.direction.displayName) · \(wind.speed.displayName)"
        case .upwindDownwind: return "Up/downwind · \(wind.speed.displayName)"
        }
    }

    @ViewBuilder
    private var suggestionBanner: some View {
        if let suggestion = store.suggestedDefense() {
            Button { store.selectSavedLine(suggestion.line.id) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested D from wind")
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
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var fairnessWarning: some View {
        let ratio = store.activeGame.specialRatio
        if store.activeGame.totalPoints >= 4, ratio > 0.25 {
            InlineWarning(
                text: String(format: "Zone/kill is %.0f%% of points — target ~20%%.", ratio * 100),
                tone: FieldTheme.warn
            )
        }
    }

    @ViewBuilder
    private var fillSuggestions: some View {
        let suggestions = store.fillSuggestions()
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                InlineWarning(
                    text: "Pods are short after injuries. Accept a fill or edit On now.",
                    tone: FieldTheme.danger
                )
                ForEach(suggestions, id: \.pod) { item in
                    Button {
                        store.applyFillSuggestion(pod: item.pod, playerId: item.player.id)
                    } label: {
                        Label(
                            "Fill \(item.pod.displayName) with \(item.player.name) — \(item.reason)",
                            systemImage: "person.badge.plus"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(FieldButtonStyle(fill: FieldTheme.warn.opacity(0.2), foreground: FieldTheme.warn, minHeight: 48))
                }
            }
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
                Text("No active players. Check injuries or pods.")
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                ForEach(players) { player in
                    HStack(spacing: 8) {
                        Button { playerForStatus = player } label: {
                            PlayerChip(player: player, points: store.points(for: player.id, scope: .game), compact: true)
                        }
                        .buttonStyle(.plain)
                        Button {
                            store.removeFromOnNow(player.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(FieldTheme.danger)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove \(player.name)")
                    }
                }
            }
            HStack(spacing: 8) {
                Button { showEditOnNow = true } label: {
                    Label("Add / edit", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(FieldButtonStyle(minHeight: 48))
                if store.activeGame.onNowOverride != nil {
                    Button("Reset to pods") { store.clearToRotation() }
                        .buttonStyle(FieldButtonStyle(fill: FieldTheme.surface, minHeight: 48))
                }
            }
            Text("Tap a name for injured/out. Use − to drop someone for a one-off call.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
        }
        .padding(14)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var nextLinesSection: some View {
        let even = store.activeGame.nextLineCards.filter { $0.kind == .even }
        let zone = store.activeGame.nextLineCards.filter { $0.kind == .zone }
        let custom = store.activeGame.nextLineCards.filter { $0.kind == .custom }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next lines")
                    .font(.title3.weight(.bold))
                Spacer()
                Button { showCustomLine = true } label: {
                    Label("Custom", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
            }
            Text("Same-size cards. Drag the handle area to reorder. Tap to put on now.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)

            sectionLabel("Suggested even")
            cardsGrid(even, badge: "EVEN", color: FieldTheme.score)

            sectionLabel("Zone interrupt")
            cardsGrid(zone, badge: "ZONE", color: FieldTheme.warn)

            sectionLabel("Custom")
            if custom.isEmpty {
                Text("No custom lines yet.")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                cardsGrid(custom, badge: "CUSTOM", color: FieldTheme.accent)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(FieldTheme.textSecondary)
    }

    private func cardsGrid(_ cards: [NextLineCard], badge: String, color: Color) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cards) { card in
                let resolved = store.resolveNextCard(card)
                NextLineCardView(
                    title: resolved.title,
                    subtitle: resolved.subtitle,
                    badge: badge,
                    badgeColor: color,
                    force: resolved.force,
                    isSelected: isCardSelected(card),
                    onTap: { store.selectNextCard(card) }
                )
                .onDrag {
                    draggingCard = card
                    return NSItemProvider(object: card.id.uuidString as NSString)
                }
                .onDrop(of: [UTType.text], delegate: NextLineDropDelegate(
                    item: card,
                    cards: store.activeGame.nextLineCards,
                    dragging: $draggingCard,
                    onMove: { store.reorderNextCards($0) }
                ))
            }
        }
    }

    private func isCardSelected(_ card: NextLineCard) -> Bool {
        switch card.kind {
        case .even:
            return !store.isSpecialLineActive && card.evenOffset == 0
        case .zone:
            if case .savedLine(let id) = store.activeGame.currentLineSource {
                return card.relatedId == id
            }
            return false
        case .custom:
            if case .custom(let id) = store.activeGame.currentLineSource {
                return card.relatedId == id
            }
            return false
        }
    }

    private var capsFooter: some View {
        Button { showCaps = true } label: {
            CapsFooter(settings: store.team.tournament)
        }
        .buttonStyle(.plain)
    }

    private var confirmBar: some View {
        HStack(spacing: 12) {
            Button { store.confirmPoint(weScored: true) } label: { Text("We scored") }
                .buttonStyle(FieldButtonStyle(fill: FieldTheme.score.opacity(0.28), foreground: FieldTheme.score, minHeight: 64))
            Button { store.confirmPoint(weScored: false) } label: { Text("They scored") }
                .buttonStyle(FieldButtonStyle(fill: FieldTheme.danger.opacity(0.22), foreground: FieldTheme.danger, minHeight: 64))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(FieldTheme.background.opacity(0.96))
    }
}

struct NextLineDropDelegate: DropDelegate {
    let item: NextLineCard
    let cards: [NextLineCard]
    @Binding var dragging: NextLineCard?
    let onMove: ([NextLineCard]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = cards.firstIndex(where: { $0.id == dragging.id }),
              let to = cards.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = cards
        updated.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        onMove(updated)
    }
}
