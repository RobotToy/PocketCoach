import SwiftUI

struct TimeTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var scope: TimeScope = .game
    @State private var roleFilter: RoleFilter = .all
    @State private var selectedPlayer: Player?

    enum RoleFilter: String, CaseIterable, Identifiable {
        case all, handlers, cutters
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .all: "All"
            case .handlers: "Handlers"
            case .cutters: "Cutters"
            }
        }
    }

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Scope", selection: $scope) {
                            ForEach(TimeScope.allCases) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        meter
                        playerSection
                        podSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPlayer) { player in
                AdjustPointsSheet(player: player, scope: scope)
            }
        }
    }

    private var meter: some View {
        let stats = store.specialRatio(scope: scope)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Rotation goal")
                .font(.title3.weight(.bold))
            Text("Even \(stats.even) · Zone/kill \(stats.special) · Total \(stats.even + stats.special)")
                .font(.subheadline)
                .foregroundStyle(FieldTheme.textSecondary)
            ProgressView(value: min(stats.ratio, 1))
                .tint(stats.ratio > 0.25 ? FieldTheme.danger : FieldTheme.score)
            if stats.even + stats.special == 0 {
                Text("No points in this scope yet.")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else if stats.ratio > 0.25 {
                InlineWarning(text: String(format: "Special lines are %.0f%%. Aim for ~20%%.", stats.ratio * 100))
            } else {
                Text(String(format: "Special lines: %.0f%% — on target.", stats.ratio * 100))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FieldTheme.score)
            }
        }
        .padding(14)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var filteredPlayers: [Player] {
        let base: [Player] = {
            switch roleFilter {
            case .all: return store.team.players
            case .handlers: return store.team.players.filter { $0.role == .handler || $0.role == .flex }
            case .cutters: return store.team.players.filter { $0.role == .cutter || $0.role == .flex }
            }
        }()
        let active = base.filter { $0.status == .active }
            .sorted {
                let lp = store.points(for: $0.id, scope: scope)
                let rp = store.points(for: $1.id, scope: scope)
                if lp != rp { return lp < rp }
                return $0.name < $1.name
            }
        let sideline = base.filter { $0.status.isSideline }
            .sorted { $0.name < $1.name }
        return active + sideline
    }

    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Players")
                    .font(.title3.weight(.bold))
                Spacer()
                Picker("Role", selection: $roleFilter) {
                    ForEach(RoleFilter.allCases) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
            Text("Least played on top. Injured at bottom. Tap a name to adjust.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)

            ForEach(filteredPlayers) { player in
                Button { selectedPlayer = player } label: {
                    HStack(spacing: 8) {
                        RoleBadge(role: player.role, compact: true)
                        Text(player.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(player.status == .active ? FieldTheme.textPrimary : FieldTheme.textSecondary)
                            .lineLimit(1)
                        if player.status.isSideline {
                            StatusBadge(status: player.status)
                        }
                        Spacer(minLength: 0)
                        Text("\(store.points(for: player.id, scope: scope))")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(FieldTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 40)
                    .background(player.status.isSideline ? FieldTheme.danger.opacity(0.08) : FieldTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var podSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pods")
                .font(.title3.weight(.bold))
            ForEach(PodId.allCases) { pod in
                let outing = store.podOutings(pod, scope: scope)
                let memberPts = store.players(in: pod).reduce(0) { $0 + store.points(for: $1.id, scope: scope) }
                HStack {
                    Text(pod.displayName)
                        .font(.headline)
                        .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                    Spacer()
                    Text("\(outing) outs")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(FieldTheme.textSecondary)
                    Text("· \(memberPts) pts")
                        .font(.subheadline.monospacedDigit())
                }
                .padding(12)
                .background(FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
