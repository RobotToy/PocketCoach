import SwiftUI

struct DefenseTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var editingLine: SavedLine?
    @State private var creatingLine = false
    @State private var editingRule: WindRule?
    @State private var creatingRule = false
    @State private var showFlip = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Team-wide D lines stay the same when you switch lineups. Multiple clam lines are fine — wind rules pick force.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)

                        HStack {
                            Text("Saved lines")
                                .font(.title3.weight(.bold))
                            Spacer()
                            Button { creatingLine = true } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }

                        ForEach(store.team.savedLines) { line in
                            Button { editingLine = line } label: {
                                savedLineRow(line)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            Text("Wind rules")
                                .font(.title3.weight(.bold))
                            Spacer()
                            Button { creatingRule = true } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }
                        Text("Left → right = wind left to right as you look toward the end you are defending this point. Rules set both the line and the force.")
                            .font(.caption)
                            .foregroundStyle(FieldTheme.textSecondary)

                        ForEach(store.team.windRules) { rule in
                            Button { editingRule = rule } label: {
                                windRuleRow(rule)
                            }
                            .buttonStyle(.plain)
                        }

                        flipSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Defense")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingLine) { SavedLineEditorSheet(line: $0) }
            .sheet(isPresented: $creatingLine) { SavedLineEditorSheet(line: nil) }
            .sheet(item: $editingRule) { WindRuleEditorSheet(rule: $0) }
            .sheet(isPresented: $creatingRule) { WindRuleEditorSheet(rule: nil) }
            .sheet(isPresented: $showFlip) { FlipPreferenceSheet() }
        }
    }

    private func savedLineRow(_ line: SavedLine) -> some View {
        let names = line.playerIds.compactMap { store.player(id: $0)?.name }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(line.name)
                    .font(.headline)
                Spacer()
                Text(line.defenseKind.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FieldTheme.accent)
            }
            Text("Default force \(line.force.displayName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FieldTheme.textSecondary)
            Text(names.isEmpty ? "No players assigned" : names)
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func windRuleRow(_ rule: WindRule) -> some View {
        let lineName = store.savedLine(id: rule.savedLineId)?.name ?? "Missing line"
        return VStack(alignment: .leading, spacing: 6) {
            Text(rule.name)
                .font(.headline)
            Text(rule.gameType.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FieldTheme.accent)
            HStack(spacing: 8) {
                if let direction = rule.direction { Text(direction.displayName) }
                if let speed = rule.minSpeed { Text("min \(speed.displayName)") }
                if let upwind = rule.pointIsUpwind {
                    Text(upwind ? "defending upwind" : "defending downwind")
                }
            }
            .font(.caption)
            .foregroundStyle(FieldTheme.textSecondary)
            Text("→ \(lineName)\(rule.forceOverride.map { " · force \($0.displayName)" } ?? "")")
                .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var flipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("If we win the flip")
                .font(.title3.weight(.bold))
            Button { showFlip = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.team.flipPreference.displayName)
                        .font(.headline)
                    Text(store.team.flipPreference.detail)
                        .font(.subheadline)
                        .foregroundStyle(FieldTheme.textSecondary)
                    if !store.team.flipNotes.isEmpty {
                        Text(store.team.flipNotes)
                            .font(.caption)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(FieldTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
