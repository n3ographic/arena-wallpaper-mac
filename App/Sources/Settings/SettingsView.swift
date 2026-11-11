import SwiftUI

/// Settings window: one tab per area.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            AccountView().tabItem { Text("Compte") }
            ChannelsView().tabItem { Text("Channels") }
            DisplayView().tabItem { Text("Affichage") }
            RotationView().tabItem { Text("Rotation") }
            GeneralView().tabItem { Text("Général") }
        }
        .frame(minWidth: 720, minHeight: 520)
        // Space pauses or resumes, right arrow shows the next image (text fields keep their keys).
        .onKeyPress(.space) {
            Task { await model.togglePause() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            Task { await model.next() }
            return .handled
        }
    }
}
