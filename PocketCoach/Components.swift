import SwiftUI
import UIKit

struct PlayerChip: View {
    let player: Player
    var points: Int? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            RoleBadge(role: player.role, compact: true)
            Text(player.name)
                .font(compact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(player.status == .active ? FieldTheme.textPrimary : FieldTheme.textSecondary)
                .lineLimit(1)
            if let number = player.number, !number.isEmpty, !compact {
                Text("#\(number)")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
            Spacer(minLength: 0)
            if player.status != .active {
                StatusBadge(status: player.status)
            } else if let points {
                Text("\(points)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(FieldTheme.textSecondary)
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .frame(minHeight: compact ? 40 : 44)
        .background(FieldTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(player.status == .active ? 1 : 0.7)
    }
}

struct NextLineCardView: View {
    let title: String
    let subtitle: String
    let badge: String
    let badgeColor: Color
    var force: Force? = nil
    var isSelected: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(badgeColor)
                        .background(badgeColor.opacity(0.18))
                        .clipShape(Capsule())
                    if let force {
                        Text(force.shortLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FieldTheme.textSecondary.opacity(0.7))
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(FieldTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(isSelected ? FieldTheme.warn.opacity(0.18) : FieldTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? FieldTheme.warn.opacity(0.7) : FieldTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ChipWidthKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct GameMenu: View {
    @ObservedObject var store: TeamStore
    @State private var showPicker = false
    @State private var showActions = false
    @State private var suppressTap = false
    @State private var chipWidth: CGFloat = 0
    @State private var confirm: GameDestructiveAction?
    @State private var pendingConfirm: GameDestructiveAction?

    private enum GameDestructiveAction: String, Identifiable {
        case reset, delete
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                guard !suppressTap else {
                    suppressTap = false
                    return
                }
                showPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                    Text(store.activeGame.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(FieldTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(FieldTheme.surfaceRaised)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .overlay {
                GeometryReader { geo in
                    Color.clear.preference(key: ChipWidthKey.self, value: geo.size.width)
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                suppressTap = true
                showPicker = false
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showActions = true
            }
            .accessibilityLabel("Current game \(store.activeGame.name)")
            .accessibilityHint("Tap to switch games. Touch and hold to reset or delete this game.")

            if showPicker, chipWidth > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.team.games.sorted(by: { $0.createdAt > $1.createdAt })) { game in
                        Button {
                            store.setActiveGame(game.id)
                            showPicker = false
                        } label: {
                            HStack(spacing: 6) {
                                Text(game.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FieldTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                                if game.id == store.team.activeGameId {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(FieldTheme.score)
                                }
                            }
                            .padding(.horizontal, 10)
                            .frame(width: chipWidth, height: 40, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    Rectangle()
                        .fill(FieldTheme.stroke)
                        .frame(height: 1)
                    Button {
                        store.createGame(named: nil, lineupId: nil)
                        showPicker = false
                    } label: {
                        Label("New game", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FieldTheme.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .frame(width: chipWidth, height: 40, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: chipWidth, alignment: .leading)
                .clipped()
                .background(FieldTheme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FieldTheme.stroke, lineWidth: 1)
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onPreferenceChange(ChipWidthKey.self) { chipWidth = $0 }
        .confirmationDialog(store.activeGame.name, isPresented: $showActions, titleVisibility: .visible) {
            Button("Reset score", role: .destructive) {
                pendingConfirm = .reset
            }
            if store.team.games.count > 1 {
                Button("Delete game", role: .destructive) {
                    pendingConfirm = .delete
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reset or delete \(store.activeGame.name). Both clear this game’s play time.")
        }
        .onChange(of: showActions) { _, isPresented in
            if !isPresented, let pendingConfirm {
                self.pendingConfirm = nil
                confirm = pendingConfirm
            }
        }
        .alert(item: $confirm) { action in
            switch action {
            case .reset:
                Alert(
                    title: Text("Reset \(store.activeGame.name)?"),
                    message: Text("Score goes to 0–0 and this game’s play time is wiped. Other games stay."),
                    primaryButton: .destructive(Text("Reset score and play time")) {
                        store.resetGame(store.activeGame.id)
                    },
                    secondaryButton: .cancel()
                )
            case .delete:
                Alert(
                    title: Text("Delete \(store.activeGame.name)?"),
                    message: Text("Removes this game and all play time logged for it. Other games stay."),
                    primaryButton: .destructive(Text("Delete game")) {
                        store.deleteGame(store.activeGame.id)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

struct LineupMenu: View {
    @ObservedObject var store: TeamStore

    var body: some View {
        Menu {
            ForEach(store.team.lineups) { lineup in
                Button {
                    store.setActiveLineup(lineup.id)
                } label: {
                    if lineup.id == store.team.activeLineupId {
                        Label(lineup.name, systemImage: "checkmark")
                    } else {
                        Text(lineup.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack.person.crop")
                Text(store.activeLineup.name)
                    .font(.subheadline.weight(.bold))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(FieldTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(FieldTheme.surfaceRaised)
            .clipShape(Capsule())
        }
        .accessibilityLabel("Active lineup \(store.activeLineup.name)")
    }
}

struct ScoreBox: View {
    let title: String
    let value: Int
    var goal: Int? = nil
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FieldTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(FieldTheme.textPrimary)
                if let goal {
                    Text("/ \(goal)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(FieldTheme.textSecondary)
                }
            }
            HStack(spacing: 10) {
                Button("-", action: onMinus)
                    .buttonStyle(FieldButtonStyle(minHeight: 44))
                Button("+", action: onPlus)
                    .buttonStyle(FieldButtonStyle(minHeight: 44))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CapsFooter: View {
    let settings: TournamentSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tournament caps")
                .font(.caption.weight(.bold))
                .foregroundStyle(FieldTheme.textSecondary)
            HStack(spacing: 8) {
                capChip("To \(settings.gameTo)")
                capChip("Half \(settings.halfCapMinutes)m")
                capChip("Soft \(settings.softCapMinutes)m")
                capChip("Hard \(settings.hardCapMinutes)m")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func capChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(FieldTheme.surfaceRaised)
            .clipShape(Capsule())
    }
}
