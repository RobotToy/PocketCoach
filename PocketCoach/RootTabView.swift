import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: TeamStore

    var body: some View {
        TabView {
            GameTab()
                .tabItem { Label("Game", systemImage: "sportscourt.fill") }
            RosterTab()
                .tabItem { Label("Roster", systemImage: "person.3.fill") }
            DefenseTab()
                .tabItem { Label("Defense", systemImage: "shield.lefthalf.filled") }
            TimeTab()
                .tabItem { Label("Time", systemImage: "clock.fill") }
        }
        .toolbarBackground(FieldTheme.surface, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootTabView()
        .environmentObject(TeamStore(team: .sample()))
}
