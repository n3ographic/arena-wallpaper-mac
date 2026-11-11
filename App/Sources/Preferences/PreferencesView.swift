import SwiftUI

/// Preferences window: account, rotation, general.
struct PreferencesView: View {
    var body: some View {
        TabView {
            AccountView().tabItem { Text("Compte") }
            RotationView().tabItem { Text("Rotation") }
            GeneralView().tabItem { Text("Général") }
        }
        .frame(width: 480, height: 360)
    }
}
