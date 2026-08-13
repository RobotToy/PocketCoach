import SwiftUI

struct RosterTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?
    @State private var movingPlayer: Player?
    @State private var renameLineup = ""
    @State private var showRename = false
    @State private var showDuplicate = false
    @State private var duplicateName = ""
    @State private var confirmDeleteLineup = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        lineupHeader
                        Text("One lineup to start. Duplicate it when the next game needs different pods.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                        collapseControl
                        podsSection
                        benchSection
                        rosterSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Label("Add player", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPlayer) {
                PlayerEditorSheet(player: nil)
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorSheet(player: player)
            }
            .sheet(item: $movingPlayer) { player in
                MovePlayerSheet(player: player)
            }
            .alert("Rename lineup", isPresented: $showRename) {
                TextField("Name", text: $renameLineup)
                Button("Save") { store.renameLineup(store.activeLineup.id, to: renameLineup) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Duplicate lineup", isPresented: $showDuplicate) {
                TextField("New name", text: $duplicateName)
                Button("Duplicate") {
                    store.duplicateActiveLineup(named: duplicateName)
                    if let copy = store.team.lineups.last {
                        store.setActiveLineup(copy.id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Copies the current pod assignments. Injury status stays global.")
            }
            .alert("Delete this lineup?", isPresented: $confirmDeleteLineup) {
                Button("Delete", role: .destructive) {
                    store.deleteLineup(store.activeLineup.id)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var lineupHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            LineupMenu(store: store)
            HStack(spacing: 8) {
                Button("Rename") {
                    renameLineup = store.activeLineup.name
                    showRename = true
                }
                .buttonStyle(FieldButtonStyle(minHeight: 44))
                Button("Duplicate") {
                    duplicateName = "\(store.activeLineup.name) copy"
                    showDuplicate = true
                }
                .buttonStyle(FieldButtonStyle(minHeight: 44))
                if store.team.lineups.count > 1 {
                    Button("Delete") { confirmDeleteLineup = true }
                        .buttonStyle(FieldButtonStyle(fill: FieldTheme.danger.opacity(0.2), foreground: FieldTheme.danger, minHeight: 44))
                }
            }
        }
    }

    private var collapseControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { store.activeLineup.collapsedCutterPods },
                set: { store.setCollapsedCutterPods($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collapse to 2 cutter pods")
                        .font(.headline)
                    Text("Use when you don’t have 8 healthy cutters. C1 and C2 rotate; C3 sits out of the even cycle.")
                        .font(.caption)
                        .foregroundStyle(FieldTheme.textSecondary)
                }
            }
            .tint(FieldTheme.accent)
            .padding(14)
            .background(FieldTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var podsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pods")
                .font(.title3.weight(.bold))
            ForEach(PodId.allCases) { pod in
                if pod == .c3 && store.activeLineup.collapsedCutterPods {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("C3 not rotating")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(FieldTheme.warn)
                        podCard(pod)
                    }
                } else {
                    podCard(pod)
                }
            }
        }
    }

    private func podCard(_ pod: PodId) -> some View {
        PodCard(
            pod: pod,
            players: store.players(in: pod),
            outings: store.team.game.outings(for: pod),
            showFill: store.fillSuggestion(for: pod),
            onFill: { store.applyFillSuggestion(for: pod) },
            onPlayerTap: { movingPlayer = $0 }
        )
    }

    private var benchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bench")
                .font(.title3.weight(.bold))
            let bench = store.benchPlayers()
            if bench.isEmpty {
                Text("Everyone is assigned to a pod.")
                    .font(.subheadline)
                    .foregroundStyle(FieldTheme.textSecondary)
            } else {
                ForEach(bench) { player in
                    Button { movingPlayer = player } label: {
                        PlayerChip(player: player, showsPoints: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All players")
                .font(.title3.weight(.bold))
            Text("Injury is global. Pod moves only change the active lineup.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
            ForEach(store.team.players) { player in
                Button { editingPlayer = player } label: {
                    HStack {
                        PlayerChip(player: player, showsPoints: true)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Active") { store.setStatus(player.id, .active) }
                    Button("Injured") { store.setStatus(player.id, .injured) }
                    Button("Out") { store.setStatus(player.id, .out) }
                }
            }
        }
    }
}
