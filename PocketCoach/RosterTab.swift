import SwiftUI

struct RosterTab: View {
    @EnvironmentObject private var store: TeamStore
    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?
    @State private var movingPlayer: Player?
    @State private var showEditPods = false
    @State private var showHistory = false
    @State private var renameLineup = ""
    @State private var showRename = false
    @State private var showDuplicate = false
    @State private var duplicateName = ""
    @State private var confirmDeleteLineup = false
    @State private var editingFillPod: PodId?

    var body: some View {
        NavigationStack {
            FieldScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        lineupHeader
                        Text("Injury is global. Pod moves only change this lineup. Short pods use the fill lists below.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                        podsSection
                        fillSection
                        sidelineSection
                        rosterSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Roster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Lineup history")
                    Button { showEditPods = true } label: {
                        Text("Edit pods")
                            .fontWeight(.semibold)
                    }
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPlayer) { PlayerEditorSheet(player: nil) }
            .sheet(item: $editingPlayer) { PlayerEditorSheet(player: $0) }
            .sheet(item: $movingPlayer) { MovePlayerSheet(player: $0) }
            .sheet(isPresented: $showEditPods) { EditPodsSheet() }
            .sheet(isPresented: $showHistory) { LineupHistorySheet() }
            .sheet(item: $editingFillPod) { FillRotationSheet(pod: $0) }
            .alert("Rename lineup", isPresented: $showRename) {
                TextField("Name", text: $renameLineup)
                Button("Save") { store.renameLineup(store.activeLineup.id, to: renameLineup) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Duplicate lineup", isPresented: $showDuplicate) {
                TextField("New name", text: $duplicateName)
                Button("Duplicate") {
                    store.duplicateActiveLineup(named: duplicateName)
                    if let copy = store.team.lineups.last { store.setActiveLineup(copy.id) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Delete this lineup?", isPresented: $confirmDeleteLineup) {
                Button("Delete", role: .destructive) { store.deleteLineup(store.activeLineup.id) }
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

    private var podsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pods")
                .font(.title3.weight(.bold))
            ForEach(PodId.allCases) { pod in
                podCard(pod)
            }
        }
    }

    private func podCard(_ pod: PodId) -> some View {
        let members = store.players(in: pod)
        let activeCount = members.filter { $0.status == .active }.count
        let countColor: Color = activeCount >= pod.capacity ? FieldTheme.score : FieldTheme.danger

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(pod.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                Text(pod.isHandler ? "Handlers" : "Cutters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FieldTheme.textSecondary)
                Spacer()
                Text("\(activeCount)/\(pod.capacity)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(countColor)
            }
            if activeCount < pod.capacity {
                InlineWarning(text: "\(pod.displayName) is short — fillers rotate in.", tone: FieldTheme.danger)
            }
            ForEach(members) { player in
                Button { movingPlayer = player } label: {
                    PlayerChip(player: player, points: store.points(for: player.id, scope: .weekend), compact: true)
                }
                .buttonStyle(.plain)
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

    private var fillSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fill rotation")
                .font(.title3.weight(.bold))
            Text("When a pod is short (injury), these people rotate in so time stays even. Keep all 3 cutter pods.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
            ForEach(PodId.allCases) { pod in
                let fillers = store.activeLineup.fillers(for: pod).compactMap { store.player(id: $0) }
                Button { editingFillPod = pod } label: {
                    HStack {
                        Text(pod.displayName)
                            .font(.headline)
                            .foregroundStyle(pod.isHandler ? FieldTheme.handler : FieldTheme.cutter)
                        Spacer()
                        Text(fillers.isEmpty ? "Add fillers" : fillers.map(\.name).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(minHeight: 48)
                    .background(FieldTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sidelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Injured / sideline")
                .font(.title3.weight(.bold))
            Text("Tap a player anywhere to move them here, or tap someone here to reactivate.")
                .font(.caption)
                .foregroundStyle(FieldTheme.textSecondary)
            let sideline = store.sidelinePlayers()
            if sideline.isEmpty {
                Text("Nobody on the sideline.")
                    .font(.subheadline)
                    .foregroundStyle(FieldTheme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FieldTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(sideline) { player in
                    Button { movingPlayer = player } label: {
                        PlayerChip(player: player, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            let unassigned = store.unassignedActivePlayers()
            if !unassigned.isEmpty {
                Text("Unassigned (active)")
                    .font(.subheadline.weight(.bold))
                    .padding(.top, 4)
                ForEach(unassigned) { player in
                    Button { movingPlayer = player } label: {
                        PlayerChip(player: player, points: store.points(for: player.id, scope: .weekend), compact: true)
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
            ForEach(store.team.players) { player in
                Button { editingPlayer = player } label: {
                    HStack {
                        PlayerChip(player: player, points: store.points(for: player.id, scope: .weekend), compact: true)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Active") { store.setStatus(player.id, .active) }
                    Button("Injured") { store.setStatus(player.id, .injured) }
                    Button("Out") { store.setStatus(player.id, .out) }
                    Button("Move to sideline") { store.setStatus(player.id, .injured) }
                }
            }
        }
    }
}
