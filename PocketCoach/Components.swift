import SwiftUI

struct PlayerChip: View {
    let player: Player
    var showsPoints: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            RoleBadge(role: player.role, compact: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(player.status == .active ? FieldTheme.textPrimary : FieldTheme.textSecondary)
                if let number = player.number, !number.isEmpty {
                    Text("#\(number)")
                        .font(.caption)
                        .foregroundStyle(FieldTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if player.status != .active {
                StatusBadge(status: player.status)
            } else if showsPoints {
                Text("\(player.gamePoints)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(FieldTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(FieldTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(player.status == .active ? 1 : 0.7)
    }
}

struct PodCard: View {
    let pod: PodId
    let players: [Player]
    let outings: Int
    var showFill: Player? = nil
    var onFill: (() -> Void)? = nil
    var onPlayerTap: ((Player) -> Void)? = nil

    var countColor: Color {
        players.filter { $0.status == .active }.count >= pod.capacity ? FieldTheme.score : FieldTheme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pod.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                Text(pod.isHandler ? "Handlers" : "Cutters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer()
                Text("\(players.filter { $0.status == .active }.count)/\(pod.capacity)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(countColor)
                Text("· \(outings) pts")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            }
            if players.filter({ $0.status == .active }).count < pod.capacity {
                InlineWarning(text: "\(pod.displayName) is short.", tone: FieldTheme.danger)
            }
            ForEach(players) { player in
                Button {
                    onPlayerTap?(player)
                } label: {
                    PlayerChip(player: player, showsPoints: true)
                }
                .buttonStyle(.plain)
            }
            if let showFill, let onFill {
                Button {
                    onFill()
                } label: {
                    Label("Move \(showFill.name) into \(pod.displayName)", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(FieldButtonStyle(fill: FieldTheme.warn.opacity(0.2), foreground: FieldTheme.warn, minHeight: 44))
            }
        }
        .padding(14)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FieldTheme.stroke, lineWidth: 1)
        )
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
                Text("Lineup: \(store.activeLineup.name)")
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
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FieldTheme.textSecondary)
            Text("\(value)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(FieldTheme.textPrimary)
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
