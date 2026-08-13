import SwiftUI

struct DefenseTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var editingLine: SavedLine?
    @State private var creatingLine = false
    @State private var editingRule: WindRule?
    @State private var creatingRule = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Team-wide D lines. They stay the same when you switch lineups.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)

                        HStack {
                            Text("Saved lines")
                                .font(.title3.weight(.bold))
                            Spacer()
                            Button {
                                creatingLine = true
                            } label: {
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
                            Button {
                                creatingRule = true
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                        }
                        Text("Left → right means wind left to right as you look toward the end you are defending this point.")
                            .font(.caption)
                            .foregroundStyle(FieldTheme.textSecondary)

                        ForEach(store.team.windRules) { rule in
                            Button { editingRule = rule } label: {
                                windRuleRow(rule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Defense")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingLine) { line in
                SavedLineEditorSheet(line: line)
            }
            .sheet(isPresented: $creatingLine) {
                SavedLineEditorSheet(line: nil)
            }
            .sheet(item: $editingRule) { rule in
                WindRuleEditorSheet(rule: rule)
            }
            .sheet(isPresented: $creatingRule) {
                WindRuleEditorSheet(rule: nil)
            }
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
            Text("Force \(line.force.displayName)")
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
                if let direction = rule.direction {
                    Text(direction.displayName)
                }
                if let speed = rule.minSpeed {
                    Text("min \(speed.displayName)")
                }
                if let upwind = rule.pointIsUpwind {
                    Text(upwind ? "defending upwind" : "defending downwind")
                }
            }
            .font(.caption)
            .foregroundStyle(FieldTheme.textSecondary)
            Text("→ \(lineName)\(rule.forceOverride.map { " · \($0.shortLabel)" } ?? "")")
                .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
