import SwiftUI
import ArenaKit

struct RotationView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackStore.self) private var playback
    @Environment(DisplayStore.self) private var display

    private var severalScreens: Bool { display.screens.count > 1 }

    var body: some View {
        Form {
            Stepper(value: Binding(
                get: { library.config.intervalMinutes },
                set: { minutes in Task { await playback.setInterval(minutes) } }
            ), in: 1...1440) {
                Text("Changer toutes les \(library.config.intervalMinutes) min")
            }
            Picker("Ordre", selection: Binding(
                get: { library.config.order },
                set: { order in Task { await playback.setOrder(order) } }
            )) {
                Text("Aléatoire").tag(RotationOrder.random)
                Text("Dans l'ordre").tag(RotationOrder.ordered)
            }
            Picker("Écrans", selection: Binding(get: { library.config.screenMode }, set: { mode in Task { await display.setScreenMode(mode) } })) {
                Text("Même image partout").tag(ScreenMode.same)
                Text("Une image par écran").tag(ScreenMode.perScreen)
                Text("Étalée sur tous les écrans").tag(ScreenMode.span)
            }
            .disabled(!severalScreens)
            Toggle("Adapter l'image à l'orientation de chaque écran", isOn: Binding(
                get: { library.config.matchOrientation },
                set: { match in Task { await display.setMatchOrientation(match) } }
            ))
            .disabled(!severalScreens || library.config.screenMode != .perScreen)
            LaunchAtLoginToggle()
        }
        .formStyle(.grouped)
    }
}
