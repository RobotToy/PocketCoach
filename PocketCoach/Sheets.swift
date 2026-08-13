import SwiftUI

struct WindSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var wind: WindState = .default

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        Picker("Game type", selection: $wind.gameType) {
                            ForEach(WindGameType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        Picker("Speed", selection: $wind.speed) {
                            ForEach(WindSpeed.allCases) { speed in
                                Text(speed.displayName).tag(speed)
                            }
                        }
                        if wind.gameType == .crosswind {
                            Picker("Direction", selection: $wind.direction) {
                                ForEach(WindDirection.allCases) { direction in
                                    Text(direction.displayName).tag(direction)
                                }
                            }
                        }
                        if wind.gameType == .upwindDownwind {
                            Toggle("Defending upwind this point", isOn: $wind.pointIsUpwind)
                        }
                    } footer: {
                        Text("Left → right means the wind blows left to right as you look toward the end you are defending this point.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Wind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateWind(wind)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { wind = store.team.game.wind }
        }
        .presentationDetents([.medium, .large])
    }
}

struct NewGameSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLineupId: UUID?
    @State private var resetGamePoints = true
    @State private var duplicateFirst = false
    @State private var duplicateName = ""

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section("Lineup") {
                        Picker("Use lineup", selection: Binding(
                            get: { selectedLineupId ?? store.team.activeLineupId },
                            set: { selectedLineupId = $0 }
                        )) {
                            ForEach(store.team.lineups) { lineup in
                                Text(lineup.name).tag(lineup.id)
                            }
                        }
                        Toggle("Duplicate active lineup first", isOn: $duplicateFirst)
                        if duplicateFirst {
                            TextField("New lineup name", text: $duplicateName)
                        }
                    }
                    Section {
                        Toggle("Reset this game’s points", isOn: $resetGamePoints)
                    } footer: {
                        Text("Weekend totals stay. Score and even/zone counters reset.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                selectedLineupId = store.team.activeLineupId
                duplicateName = "\(store.activeLineup.name) game"
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func start() {
        var lineupId = selectedLineupId ?? store.team.activeLineupId
        if duplicateFirst {
            store.duplicateActiveLineup(named: duplicateName)
            if let copy = store.team.lineups.last {
                lineupId = copy.id
            }
        }
        store.startNewGame(lineupId: lineupId, resetGamePoints: resetGamePoints)
        dismiss()
    }
}

struct TeamSettingsSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmRestore = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section("Team") {
                        TextField("Team name", text: $name)
                        HStack {
                            Text("Join code")
                            Spacer()
                            Text(store.team.joinCode)
                                .font(.title3.weight(.bold).monospaced())
                        }
                        Button("Regenerate code") { store.regenerateJoinCode() }
                    }
                    Section {
                        Text("Data is saved on this phone only. Multi-phone Firebase sync is not wired yet — use the same join code later when you add GoogleService-Info.plist.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    Section {
                        Button("Restore sample roster", role: .destructive) { confirmRestore = true }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setTeamName(name)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { name = store.team.name }
            .alert("Replace all data with the sample team?", isPresented: $confirmRestore) {
                Button("Restore", role: .destructive) {
                    store.restoreSampleData()
                    name = store.team.name
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct PlayerStatusSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let player: Player

    var body: some View {
        NavigationStack {
            FieldScreen {
                VStack(spacing: 12) {
                    Text(player.name)
                        .font(.title2.weight(.bold))
                    RoleBadge(role: player.role)
                    StatusBadge(status: player.status)
                    Button("Active") {
                        store.setStatus(player.id, .active)
                        dismiss()
                    }
                    .buttonStyle(FieldButtonStyle(fill: FieldTheme.score.opacity(0.25), foreground: FieldTheme.score))
                    Button("Injured") {
                        store.setStatus(player.id, .injured)
                        dismiss()
                    }
                    .buttonStyle(FieldButtonStyle(fill: FieldTheme.warn.opacity(0.25), foreground: FieldTheme.warn))
                    Button("Out") {
                        store.setStatus(player.id, .out)
                        dismiss()
                    }
                    .buttonStyle(FieldButtonStyle(fill: FieldTheme.danger.opacity(0.25), foreground: FieldTheme.danger))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

struct MovePlayerSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let player: Player

    var body: some View {
        NavigationStack {
            FieldScreen {
                List {
                    Section("Move \(player.name)") {
                        Button("Bench") {
                            store.assign(playerId: player.id, to: nil)
                            dismiss()
                        }
                        ForEach(PodId.allCases) { pod in
                            Button("\(pod.displayName) · \(pod.isHandler ? "Handlers" : "Cutters")") {
                                store.assign(playerId: player.id, to: pod)
                                dismiss()
                            }
                        }
                    }
                    Section("Status") {
                        Button("Active") { store.setStatus(player.id, .active); dismiss() }
                        Button("Injured") { store.setStatus(player.id, .injured); dismiss() }
                        Button("Out") { store.setStatus(player.id, .out); dismiss() }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Reassign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PlayerEditorSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let player: Player?

    @State private var name = ""
    @State private var number = ""
    @State private var role: PlayerRole = .cutter
    @State private var floaters: Set<PodId> = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section("Player") {
                        TextField("Name", text: $name)
                        TextField("Number (optional)", text: $number)
                            .keyboardType(.numberPad)
                        Picker("Role", selection: $role) {
                            ForEach(PlayerRole.allCases) { r in
                                Text(r.displayName).tag(r)
                            }
                        }
                    }
                    Section {
                        ForEach(PodId.allCases) { pod in
                            Toggle("Also fill \(pod.displayName)", isOn: Binding(
                                get: { floaters.contains(pod) },
                                set: { on in
                                    if on { floaters.insert(pod) } else { floaters.remove(pod) }
                                }
                            ))
                        }
                    } header: {
                        Text("Floater")
                    } footer: {
                        Text("If a pod is short, this player can automatically fill it when that pod goes out.")
                    }
                    if let player {
                        Section {
                            Button("Delete player", role: .destructive) { confirmDelete = true }
                        } footer: {
                            Text("Current status: \(player.status.displayName)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(player == nil ? "Add player" : "Edit player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let player {
                    name = player.name
                    number = player.number ?? ""
                    role = player.role
                    floaters = Set(player.floaterPodIds)
                }
            }
            .alert("Delete \(player?.name ?? "player")?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let player { store.deletePlayer(player.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        if let player {
            store.updatePlayer(player.id, name: name, number: number, role: role, floaterPodIds: Array(floaters))
        } else {
            store.addPlayer(name: name, number: number, role: role)
        }
        dismiss()
    }
}

struct SavedLineEditorSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let line: SavedLine?

    @State private var name = ""
    @State private var kind: DefenseKind = .clam
    @State private var force: Force = .backhand
    @State private var selected: [UUID] = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        TextField("Name", text: $name)
                        Picker("Defense", selection: $kind) {
                            ForEach(DefenseKind.allCases) { k in Text(k.displayName).tag(k) }
                        }
                        Picker("Force", selection: $force) {
                            ForEach(Force.allCases) { f in Text(f.displayName).tag(f) }
                        }
                    }
                    Section {
                        Text("\(selected.count) / 7 selected")
                            .foregroundStyle(selected.count == 7 ? FieldTheme.score : FieldTheme.warn)
                        ForEach(store.team.players) { player in
                            Button {
                                toggle(player.id)
                            } label: {
                                HStack {
                                    PlayerChip(player: player)
                                    if selected.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FieldTheme.score)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Players")
                    }
                    if line != nil {
                        Section {
                            Button("Delete line", role: .destructive) { confirmDelete = true }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(line == nil ? "New D line" : "Edit D line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let line {
                    name = line.name
                    kind = line.defenseKind
                    force = line.force
                    selected = line.playerIds
                }
            }
            .alert("Delete this D line?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let line { store.deleteSavedLine(line.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func toggle(_ id: UUID) {
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else if selected.count < 7 {
            selected.append(id)
        }
    }

    private func save() {
        let saved = SavedLine(
            id: line?.id ?? UUID(),
            name: name,
            defenseKind: kind,
            force: force,
            playerIds: selected
        )
        store.upsertSavedLine(saved)
        dismiss()
    }
}

struct WindRuleEditorSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let rule: WindRule?

    @State private var name = ""
    @State private var gameType: WindGameType = .crosswind
    @State private var useDirection = true
    @State private var direction: WindDirection = .leftToRight
    @State private var useMinSpeed = false
    @State private var minSpeed: WindSpeed = .strong
    @State private var useUpwind = false
    @State private var pointIsUpwind = false
    @State private var savedLineId: UUID?
    @State private var useForceOverride = false
    @State private var forceOverride: Force = .backhand
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        TextField("Rule name", text: $name)
                        Picker("Game type", selection: $gameType) {
                            ForEach(WindGameType.allCases) { t in Text(t.displayName).tag(t) }
                        }
                        Toggle("Match direction", isOn: $useDirection)
                        if useDirection {
                            Picker("Direction", selection: $direction) {
                                ForEach(WindDirection.allCases) { d in Text(d.displayName).tag(d) }
                            }
                        }
                        Toggle("Minimum speed", isOn: $useMinSpeed)
                        if useMinSpeed {
                            Picker("Min speed", selection: $minSpeed) {
                                ForEach(WindSpeed.allCases) { s in Text(s.displayName).tag(s) }
                            }
                        }
                        if gameType == .upwindDownwind {
                            Toggle("Match upwind / downwind point", isOn: $useUpwind)
                            if useUpwind {
                                Toggle("Defending upwind", isOn: $pointIsUpwind)
                            }
                        }
                    }
                    Section("Call this line") {
                        if store.team.savedLines.isEmpty {
                            Text("Add a saved D line first.")
                                .foregroundStyle(FieldTheme.textSecondary)
                        } else {
                            Picker("Saved line", selection: Binding(
                                get: { savedLineId ?? store.team.savedLines[0].id },
                                set: { savedLineId = $0 }
                            )) {
                                ForEach(store.team.savedLines) { line in
                                    Text(line.name).tag(line.id)
                                }
                            }
                        }
                        Toggle("Override force", isOn: $useForceOverride)
                        if useForceOverride {
                            Picker("Force", selection: $forceOverride) {
                                ForEach(Force.allCases) { f in Text(f.displayName).tag(f) }
                            }
                        }
                    }
                    if rule != nil {
                        Section {
                            Button("Delete rule", role: .destructive) { confirmDelete = true }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(rule == nil ? "New wind rule" : "Edit wind rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.team.savedLines.isEmpty)
                }
            }
            .onAppear { load() }
            .alert("Delete this rule?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let rule { store.deleteWindRule(rule.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func load() {
        savedLineId = store.team.savedLines.first?.id
        guard let rule else { return }
        name = rule.name
        gameType = rule.gameType
        useDirection = rule.direction != nil
        direction = rule.direction ?? .leftToRight
        useMinSpeed = rule.minSpeed != nil
        minSpeed = rule.minSpeed ?? .strong
        useUpwind = rule.pointIsUpwind != nil
        pointIsUpwind = rule.pointIsUpwind ?? false
        savedLineId = rule.savedLineId
        useForceOverride = rule.forceOverride != nil
        forceOverride = rule.forceOverride ?? .backhand
    }

    private func save() {
        guard let savedLineId else { return }
        let saved = WindRule(
            id: rule?.id ?? UUID(),
            name: name,
            gameType: gameType,
            direction: useDirection ? direction : nil,
            minSpeed: useMinSpeed ? minSpeed : nil,
            pointIsUpwind: (gameType == .upwindDownwind && useUpwind) ? pointIsUpwind : nil,
            savedLineId: savedLineId,
            forceOverride: useForceOverride ? forceOverride : nil
        )
        store.upsertWindRule(saved)
        dismiss()
    }
}
