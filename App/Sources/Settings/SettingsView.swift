import SwiftUI

/// Settings window: one tab per area.
struct SettingsView: View {
    var body: some View {
        TabView {
            AccountView().tabItem { Text("Compte") }
            ChannelsView().tabItem { Text("Channels") }
            DisplayView().tabItem { Text("Affichage") }
            RotationView().tabItem { Text("Rotation") }
            SensitiveContentView().tabItem { Text("Contenu sensible") }
            GeneralView().tabItem { Text("Général") }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}
