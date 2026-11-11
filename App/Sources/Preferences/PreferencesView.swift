import SwiftUI

/// Preferences window: account, rotation, general.
struct PreferencesView: View {
    var body: some View {
        TabView {
            AccountView().tabItem { Text("Compte") }
            RotationView().tabItem { Text("Lecture") }
            GeneralView().tabItem { Text("Général") }
        }
    }
}
