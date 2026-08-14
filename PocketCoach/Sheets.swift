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
                            ForEach(WindGameType.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("Speed", selection: $wind.speed) {
                            ForEach(WindSpeed.allCases) { Text($0.displayName).tag($0) }
                        }
                        if wind.gameType == .crosswind {
                            Picker("Direction", selection: $wind.direction) {
                                ForEach(WindDirection.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        if wind.gameType == .upwindDownwind {
                            Toggle("Defending upwind this point", isOn: $wind.pointIsUpwind)
                        }
                    } footer: {
                        Text("Left → right means wind left to right as you look toward the end you are defending. Matching wind rules pick both the D line and force.")
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
            .onAppear { wind = store.activeGame.wind }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TournamentCapsSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var gameTo = 15
    @State private var half = 45
    @State private var soft = 70
    @State private var hard = 80

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        Stepper("Game to \(gameTo)", value: $gameTo, in: 7...21)
                        Stepper("Half cap \(half) min", value: $half, in: 20...90, step: 5)
                        Stepper("Soft cap \(soft) min", value: $soft, in: 30...120, step: 5)
                        Stepper("Hard cap \(hard) min", value: $hard, in: 40...150, step: 5)
                    } footer: {
                        Text("Set once for the tournament. Same on every game.")
                    }
                    Section("Presets") {
                        Button("USA Club (15 / 45 / 70 / 80)") {
                            gameTo = 15; half = 45; soft = 70; hard = 80
                        }
                        Button("To 13 / soft 55 / hard 65") {
                            gameTo = 13; half = 40; soft = 55; hard = 65
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Caps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateTournament(TournamentSettings(
                            gameTo: gameTo,
                            halfCapMinutes: half,
                            softCapMinutes: soft,
                            hardCapMinutes: hard
                        ))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                let t = store.team.tournament
                gameTo = t.gameTo
                half = t.halfCapMinutes
                soft = t.softCapMinutes
                hard = t.hardCapMinutes
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TeamSettingsSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmRestore = false
    @State private var confirmResetPlayTime = false
    @State private var confirmResetPlayTimeAgain = false
    @State private var pendingSecondResetConfirm = false
    @State private var renameGame = ""
    @State private var showRenameGame = false

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
                    Section("Games on this phone") {
                        ForEach(store.team.games.sorted(by: { $0.createdAt > $1.createdAt })) { game in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(game.name).font(.headline)
                                    Text("\(game.usScore)–\(game.themScore)")
                                        .font(.caption)
                                        .foregroundStyle(FieldTheme.textSecondary)
                                }
                                Spacer()
                                if game.id == store.team.activeGameId {
                                    Text("Current")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(FieldTheme.score)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { store.setActiveGame(game.id) }
                        }
                        Button("Rename current game") {
                            renameGame = store.activeGame.name
                            showRenameGame = true
                        }
                        Button("New game") {
                            store.createGame(named: nil, lineupId: nil)
                        }
                    }
                    Section {
                        Text("Games stay on this phone. New game never overwrites an old one — it creates Game 2, Game 3, … and switches the dropdown.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    Section("Play time") {
                        Text("Zeros player points, pod outings, and even/zone counts on every game. Roster names, lineups, and scores stay.")
                            .font(.subheadline)
                            .foregroundStyle(FieldTheme.textSecondary)
                        Button("Reset all roster play time", role: .destructive) {
                            confirmResetPlayTime = true
                        }
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
            .alert("Rename game", isPresented: $showRenameGame) {
                TextField("Name", text: $renameGame)
                Button("Save") { store.renameGame(store.activeGame.id, to: renameGame) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Reset all play time?", isPresented: $confirmResetPlayTime) {
                Button("Continue", role: .destructive) {
                    pendingSecondResetConfirm = true
                }
                Button("Cancel", role: .cancel) {
                    pendingSecondResetConfirm = false
                }
            } message: {
                Text("This clears attendance for every game on this phone. Roster and scores stay.")
            }
            .onChange(of: confirmResetPlayTime) { _, isPresented in
                if !isPresented, pendingSecondResetConfirm {
                    pendingSecondResetConfirm = false
                    confirmResetPlayTimeAgain = true
                }
            }
            .alert("Really wipe play time?", isPresented: $confirmResetPlayTimeAgain) {
                Button("Wipe play time", role: .destructive) {
                    store.resetAllPlayTime()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. Every player’s points and pod outings will go to zero.")
            }
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

struct EditOnNowSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [UUID] = []

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        Text("\(selected.count) on field")
                            .foregroundStyle(selected.count == 7 ? FieldTheme.score : FieldTheme.warn)
                    }
                    Section("On field") {
                        ForEach(selected.compactMap { store.player(id: $0) }) { player in
                            Button {
                                selected.removeAll { $0 == player.id }
                            } label: {
                                HStack {
                                    PlayerChip(player: player, compact: true)
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(FieldTheme.danger)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Section("Add from roster") {
                        ForEach(store.team.players.filter { $0.status == .active && !selected.contains($0.id) }) { player in
                            Button {
                                selected.append(player.id)
                            } label: {
                                HStack {
                                    PlayerChip(player: player, compact: true)
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(FieldTheme.score)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit on now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        store.setOnNowPlayers(selected)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { selected = store.currentLinePlayers().map(\.id) }
        }
    }
}

struct CustomLineSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Custom"
    @State private var selected: [UUID] = []

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    TextField("Name", text: $name)
                    Section("Players (\(selected.count))") {
                        ForEach(store.team.players.filter { $0.status == .active }) { player in
                            Button {
                                if let i = selected.firstIndex(of: player.id) {
                                    selected.remove(at: i)
                                } else {
                                    selected.append(player.id)
                                }
                            } label: {
                                HStack {
                                    PlayerChip(player: player, compact: true)
                                    if selected.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FieldTheme.score)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Custom line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addCustomLine(name: name, playerIds: selected)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
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
                    Text(player.name).font(.title2.weight(.bold))
                    RoleBadge(role: player.role)
                    StatusBadge(status: player.status)
                    Button("Active") { store.setStatus(player.id, .active); dismiss() }
                        .buttonStyle(FieldButtonStyle(fill: FieldTheme.score.opacity(0.25), foreground: FieldTheme.score))
                    Button("Injured") { store.setStatus(player.id, .injured); dismiss() }
                        .buttonStyle(FieldButtonStyle(fill: FieldTheme.warn.opacity(0.25), foreground: FieldTheme.warn))
                    Button("Out") { store.setStatus(player.id, .out); dismiss() }
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
                        ForEach(PodId.allCases) { pod in
                            Button("\(pod.displayName)") {
                                store.setStatus(player.id, .active)
                                store.assign(playerId: player.id, to: pod)
                                dismiss()
                            }
                        }
                        Button("Unassign from pods") {
                            store.setStatus(player.id, .active)
                            store.assign(playerId: player.id, to: nil)
                            dismiss()
                        }
                    }
                    Section("Sideline") {
                        Button("Injured") { store.setStatus(player.id, .injured); dismiss() }
                        Button("Out") { store.setStatus(player.id, .out); dismiss() }
                        Button("Back to active") { store.setStatus(player.id, .active); dismiss() }
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
                            ForEach(PlayerRole.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                    if let player {
                        Section {
                            Button("Delete player", role: .destructive) { confirmDelete = true }
                        } footer: {
                            Text("Status: \(player.status.displayName)")
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
            store.updatePlayer(player.id, name: name, number: number, role: role)
        } else {
            store.addPlayer(name: name, number: number, role: role)
        }
        dismiss()
    }
}

struct EditPodsSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var pods: [PodId: [UUID]] = [:]
    @State private var fill: [PodId: [UUID]] = [:]

    var body: some View {
        NavigationStack {
            FieldScreen {
                List {
                    Section {
                        Text("Saving archives the previous pod setup in History.")
                            .font(.caption)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    ForEach(PodId.allCases) { pod in
                        Section(pod.displayName) {
                            ForEach(store.team.players.filter { $0.status != .out }) { player in
                                let on = (pods[pod] ?? []).contains(player.id)
                                Button {
                                    toggle(player.id, in: pod)
                                } label: {
                                    HStack {
                                        Text(player.name)
                                        Spacer()
                                        if on {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(FieldTheme.score)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit pods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.replaceActiveLineupPods(pods, fillRotation: fill)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                pods = store.activeLineup.pods
                fill = store.activeLineup.fillRotation
            }
        }
    }

    private func toggle(_ id: UUID, in pod: PodId) {
        if (pods[pod] ?? []).contains(id) {
            pods[pod] = (pods[pod] ?? []).filter { $0 != id }
            return
        }
        for key in PodId.allCases {
            pods[key] = (pods[key] ?? []).filter { $0 != id }
        }
        var list = pods[pod] ?? []
        list.append(id)
        pods[pod] = list
    }
}

struct LineupHistorySheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FieldScreen {
                List {
                    if store.team.lineupHistory.isEmpty {
                        Text("No archived lineups yet. Editing pods saves a snapshot here.")
                            .foregroundStyle(FieldTheme.textSecondary)
                    } else {
                        ForEach(store.team.lineupHistory) { snap in
                            Button {
                                store.restoreSnapshot(snap.id)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(snap.name).font(.headline)
                                    Text(snap.savedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(FieldTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct FillRotationSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let pod: PodId
    @State private var selected: [UUID] = []

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        Text("Order matters — first available active person fills first, then the list rotates so no one is stuck on forever.")
                            .font(.caption)
                            .foregroundStyle(FieldTheme.textSecondary)
                    }
                    Section("Fillers for \(pod.displayName)") {
                        ForEach(selected.compactMap { store.player(id: $0) }) { player in
                            Button {
                                selected.removeAll { $0 == player.id }
                            } label: {
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    Image(systemName: "minus.circle.fill").foregroundStyle(FieldTheme.danger)
                                }
                            }
                        }
                    }
                    Section("Add") {
                        ForEach(store.team.players.filter {
                            $0.status == .active
                                && store.isCompatible($0, with: pod)
                                && !selected.contains($0.id)
                                && !(store.activeLineup.playerIds(in: pod).contains($0.id))
                        }) { player in
                            Button {
                                selected.append(player.id)
                            } label: {
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    Text(store.homePod(of: player.id)?.displayName ?? "—")
                                        .foregroundStyle(FieldTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("\(pod.displayName) fills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setFillRotation(for: pod, playerIds: selected)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear { selected = store.activeLineup.fillers(for: pod) }
        }
    }
}

struct FlipPreferenceSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    @State private var pref: FlipPreference = .defense
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section("If we win the flip") {
                        ForEach(FlipPreference.allCases) { option in
                            Button {
                                pref = option
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.displayName).font(.headline)
                                        Text(option.detail)
                                            .font(.caption)
                                            .foregroundStyle(FieldTheme.textSecondary)
                                    }
                                    Spacer()
                                    if pref == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FieldTheme.score)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Section("Notes") {
                        TextField("e.g. take D unless strong wind", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Flip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setFlipPreference(pref, notes: notes)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                pref = store.team.flipPreference
                notes = store.team.flipNotes
            }
        }
    }
}

struct AdjustPointsSheet: View {
    @EnvironmentObject private var store: TeamStore
    @Environment(\.dismiss) private var dismiss
    let player: Player
    let scope: TimeScope

    var body: some View {
        NavigationStack {
            FieldScreen {
                VStack(spacing: 16) {
                    Text(player.name).font(.title2.weight(.bold))
                    Text("\(store.points(for: player.id, scope: scope)) pts · \(scope.displayName)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(FieldTheme.textSecondary)
                    HStack(spacing: 12) {
                        Button("−1") {
                            store.adjustPlayerPoints(id: player.id, delta: -1, scope: scope)
                        }
                        .buttonStyle(FieldButtonStyle(minHeight: 56))
                        Button("+1") {
                            store.adjustPlayerPoints(id: player.id, delta: 1, scope: scope)
                        }
                        .buttonStyle(FieldButtonStyle(fill: FieldTheme.score.opacity(0.25), foreground: FieldTheme.score, minHeight: 56))
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
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
                            ForEach(DefenseKind.allCases) { Text($0.displayName).tag($0) }
                        }
                        Picker("Default force", selection: $force) {
                            ForEach(Force.allCases) { Text($0.displayName).tag($0) }
                        }
                    } footer: {
                        Text("Wind rules can override force (e.g. same clam line, BH vs flick).")
                    }
                    Section {
                        Text("\(selected.count) / 7 selected")
                            .foregroundStyle(selected.count == 7 ? FieldTheme.score : FieldTheme.warn)
                        ForEach(store.team.players) { player in
                            Button { toggle(player.id) } label: {
                                HStack {
                                    PlayerChip(player: player, compact: true)
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
        store.upsertSavedLine(SavedLine(
            id: line?.id ?? UUID(),
            name: name,
            defenseKind: kind,
            force: force,
            playerIds: selected
        ))
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
    @State private var useForceOverride = true
    @State private var forceOverride: Force = .backhand
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            FieldScreen {
                Form {
                    Section {
                        TextField("Rule name", text: $name)
                        Picker("Game type", selection: $gameType) {
                            ForEach(WindGameType.allCases) { Text($0.displayName).tag($0) }
                        }
                        Toggle("Match direction", isOn: $useDirection)
                        if useDirection {
                            Picker("Direction", selection: $direction) {
                                ForEach(WindDirection.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        Toggle("Minimum speed", isOn: $useMinSpeed)
                        if useMinSpeed {
                            Picker("Min speed", selection: $minSpeed) {
                                ForEach(WindSpeed.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        if gameType == .upwindDownwind {
                            Toggle("Match upwind / downwind point", isOn: $useUpwind)
                            if useUpwind {
                                Toggle("Defending upwind", isOn: $pointIsUpwind)
                            }
                        }
                    }
                    Section("Call this line + force") {
                        if store.team.savedLines.isEmpty {
                            Text("Add a saved D line first.")
                        } else {
                            Picker("Saved line", selection: Binding(
                                get: { savedLineId ?? store.team.savedLines[0].id },
                                set: { savedLineId = $0 }
                            )) {
                                ForEach(store.team.savedLines) { Text($0.name).tag($0.id) }
                            }
                        }
                        Toggle("Override force", isOn: $useForceOverride)
                        if useForceOverride {
                            Picker("Force", selection: $forceOverride) {
                                ForEach(Force.allCases) { Text($0.displayName).tag($0) }
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
        store.upsertWindRule(WindRule(
            id: rule?.id ?? UUID(),
            name: name,
            gameType: gameType,
            direction: useDirection ? direction : nil,
            minSpeed: useMinSpeed ? minSpeed : nil,
            pointIsUpwind: (gameType == .upwindDownwind && useUpwind) ? pointIsUpwind : nil,
            savedLineId: savedLineId,
            forceOverride: useForceOverride ? forceOverride : nil
        ))
        dismiss()
    }
}
