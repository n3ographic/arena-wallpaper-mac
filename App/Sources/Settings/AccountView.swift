import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsTokenField = false
    @State private var token = ""

    var body: some View {
        Form {
            if model.isConnected {
                LabeledContent("Are.na", value: "Connecté")
                Button("Se déconnecter") { model.disconnect() }
            } else {
                Button("Se connecter à Are.na") { Task { await model.connect() } }
                DisclosureGroup("Utiliser un token personnel", isExpanded: $showsTokenField) {
                    SecureField("Token personnel", text: $token)
                    Button("Enregistrer le token") {
                        Task {
                            await model.connect(personalToken: token)
                            token = ""
                        }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let error = model.lastError {
                Text(error).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
