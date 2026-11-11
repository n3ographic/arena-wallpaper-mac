import SwiftUI

struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @Environment(ErrorCenter.self) private var errors
    @State private var showsTokenField = false
    @State private var token = ""

    var body: some View {
        Form {
            if account.isConnected {
                LabeledContent("Are.na") { Text("Connecté") }
                Button("Se déconnecter") { account.disconnect() }
            } else {
                Button("Se connecter à Are.na") { Task { await account.connect() } }
                DisclosureGroup("Utiliser un token personnel", isExpanded: $showsTokenField) {
                    SecureField("Token personnel", text: $token)
                    Button("Enregistrer le token") {
                        Task {
                            await account.connect(personalToken: token)
                            token = ""
                        }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let error = errors.message {
                Text(error).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}
