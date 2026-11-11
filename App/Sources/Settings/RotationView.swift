import SwiftUI
import ArenaKit

struct RotationView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackStore.self) private var playback

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
        }
        .formStyle(.grouped)
    }
}
