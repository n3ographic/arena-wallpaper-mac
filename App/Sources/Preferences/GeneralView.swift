import SwiftUI

struct GeneralView: View {
    @Environment(ErrorCenter.self) private var errors
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @StateObject private var updates = UpdateChecker()

    var body: some View {
        Form {
            Toggle("Lancer au démarrage", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
            if let page = updates.newerRelease {
                LabeledContent("Version %@ disponible".localizedFormat(updates.newerVersion)) {
                    Link("Télécharger", destination: page)
                }
            }
        }
        .formStyle(.grouped)
        .task { await updates.check() }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
        } catch {
            errors.report(error)
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}

private extension String {
    func localizedFormat(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}
