import SwiftUI

/// Settings window: one tab per area (more tabs arrive with later tasks).
struct SettingsView: View {
    var body: some View {
        TabView {
            AccountView().tabItem { Text("Compte") }
            ChannelsView().tabItem { Text("Channels") }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}
