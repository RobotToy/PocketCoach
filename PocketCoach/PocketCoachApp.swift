import SwiftUI

@main
struct PocketCoachApp: App {
    @StateObject private var store = TeamStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .tint(FieldTheme.accent)
        }
    }
}
