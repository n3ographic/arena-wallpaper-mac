import SwiftUI

struct GeneralView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Toggle("Lancer au démarrage", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        }
        .formStyle(.grouped)
    }
}
