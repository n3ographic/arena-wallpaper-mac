import SwiftUI
import ArenaKit

struct RotationView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Stepper(value: Binding(
                get: { model.config.intervalMinutes },
                set: { minutes in Task { await model.updateRotation { $0.intervalMinutes = max(1, minutes) } } }
            ), in: 1...1440) {
                Text("Changer toutes les \(model.config.intervalMinutes) min")
            }
            Picker("Ordre", selection: Binding(
                get: { model.config.order },
                set: { order in Task { await model.updateRotation { $0.order = order } } }
            )) {
                Text("Aléatoire").tag(RotationOrder.random)
                Text("Dans l'ordre").tag(RotationOrder.ordered)
            }
        }
        .formStyle(.grouped)
    }
}
