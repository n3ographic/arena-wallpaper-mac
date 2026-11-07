import AppKit
import SwiftUI

struct SensitiveContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Toggle("Masquer le contenu sensible", isOn: Binding(
                get: { model.config.hideSensitive },
                set: { hide in Task { await model.updateRotation { $0.hideSensitive = hide } } }
            ))
            LabeledContent("Détection", value: model.sensitiveDetectionActive ? "Active" : "Inactive")
            if !model.sensitiveDetectionActive {
                Text("Pour que l'app masque les images sensibles, active l'avertissement de contenu sensible dans Réglages Système, section Confidentialité et sécurité.")
                    .foregroundStyle(.secondary)
                Button("Ouvrir Réglages Système") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                }
            }
            LabeledContent("Images à vérifier", value: "\(model.flaggedCount)")
            Text("L'analyse se fait sur ton Mac. Aucun résultat n'est envoyé.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .task { await model.refreshSensitiveStatus() }
    }
}
