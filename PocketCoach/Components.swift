import SwiftUI

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

struct GameMenu: View {
    @ObservedObject var store: TeamStore

    var body: some View {
        Menu {
            ForEach(store.team.games.sorted(by: { $0.createdAt > $1.createdAt })) { game in
                Button {
                    store.setActiveGame(game.id)
                } label: {
                    if game.id == store.team.activeGameId {
                        Label(game.name, systemImage: "checkmark")
                    } else {
                        Text(game.name)
                    }
                }
            }
            Divider()
            Button {
                store.createGame(named: nil, lineupId: nil)
            } label: {
                Label("New game", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                Text(store.activeGame.name)
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
        .accessibilityLabel("Current game \(store.activeGame.name)")
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
