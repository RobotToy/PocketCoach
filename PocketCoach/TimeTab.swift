import SwiftUI

struct TimeTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var confirmResetWeekend = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        meter
                        podSection
                        playerSection
                        Button("Reset weekend points") { confirmResetWeekend = true }
                            .buttonStyle(FieldButtonStyle(fill: FieldTheme.danger.opacity(0.2), foreground: FieldTheme.danger))
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset all play time?", isPresented: $confirmResetWeekend) {
                Button("Reset", role: .destructive) { store.resetWeekendPoints() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears weekend and game points for everyone, plus even/zone counters.")
            }
        }
    }

    private var meter: some View {
        let game = store.team.game
        let ratio = game.specialRatio
        return VStack(alignment: .leading, spacing: 10) {
            Text("80 / 20")
                .font(.title3.weight(.bold))
            Text("Even rotation \(game.evenPoints) · Zone/kill \(game.specialPoints) · Total \(game.totalPoints)")
                .font(.subheadline)
                .foregroundStyle(FieldTheme.textSecondary)
            ProgressView(value: min(ratio, 1))
                .tint(ratio > 0.25 ? FieldTheme.danger : FieldTheme.score)
            if game.totalPoints == 0 {
                Text("No points yet this game.")
                    .font(.caption)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else if ratio > 0.25 {
                InlineWarning(
                    text: String(format: "Special lines are %.0f%% of points. Aim for ~20%%.", ratio * 100)
                )
            } else {
                Text(String(format: "Special lines: %.0f%% — on target.", ratio * 100))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FieldTheme.score)
            }
        }
        .padding(14)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var podSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pods this game")
                .font(.title3.weight(.bold))
            ForEach(PodId.allCases) { pod in
                let members = store.players(in: pod)
                let outing = store.team.game.outings(for: pod)
                HStack {
                    Text(pod.displayName)
                        .font(.headline)
                        .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                    Spacer()
                    Text("\(outing) even outs")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(FieldTheme.textSecondary)
                    Text("· \(members.reduce(0) { $0 + $1.gamePoints }) pts")
                        .font(.subheadline.monospacedDigit())
                }
                .padding(12)
                .background(FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var playerSection: some View {
        let median = medianPoints(store.team.players.map(\.weekendPoints))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Players")
                .font(.title3.weight(.bold))
            Text("Weekend / this game. Highlighted if well above median.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
            ForEach(store.team.players.sorted { $0.weekendPoints > $1.weekendPoints }) { player in
                HStack(spacing: 10) {
                    RoleBadge(role: player.role, compact: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.headline)
                        if player.status != .active {
                            StatusBadge(status: player.status)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(player.weekendPoints)")
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("g \(player.gamePoints)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    VStack(spacing: 4) {
                        Button("+") { store.adjustPlayerPoints(id: player.id, weekendDelta: 1, gameDelta: 1) }
                            .buttonStyle(FieldButtonStyle(minHeight: 44))
                        Button("-") { store.adjustPlayerPoints(id: player.id, weekendDelta: -1, gameDelta: -1) }
                            .buttonStyle(FieldButtonStyle(minHeight: 44))
                    }
                    .frame(width: 56)
                }
                .padding(12)
                .background(isHot(player.weekendPoints, median: median) ? FieldTheme.warn.opacity(0.16) : FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func medianPoints(_ values: [Int]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Double(sorted[mid - 1] + sorted[mid]) / 2
        }
        return Double(sorted[mid])
    }

    private func isHot(_ points: Int, median: Double) -> Bool {
        guard median > 0 else { return false }
        return Double(points) >= median * 1.4 && points - Int(median.rounded()) >= 2
    }
}
