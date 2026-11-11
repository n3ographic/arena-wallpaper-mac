import SwiftUI

struct GeneralView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var updates = UpdateChecker()

    var body: some View {
        Form {
            Toggle("Lancer au démarrage", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            if let page = updates.newerRelease {
                LabeledContent("Version %@ disponible".localizedFormat(updates.newerVersion)) {
                    Link("Télécharger", destination: page)
                }
            }
        }
        .formStyle(.grouped)
        .task { await updates.check() }
    }
}

private extension String {
    func localizedFormat(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}
