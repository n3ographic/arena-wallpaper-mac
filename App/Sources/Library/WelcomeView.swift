import AppKit
import SwiftUI

/// What an empty library shows: sign in right away, or add a public channel without an account.
struct WelcomeView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(AccountStore.self) private var account
    @Environment(ErrorCenter.self) private var errors

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)
            Text("Bienvenue dans Arena Wallpaper").font(.title2.weight(.semibold))
            if account.isConnected {
                Text("Tu es connecté. Ajoute un channel avec le champ en bas de la barre latérale : colle son lien ou son slug.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("Connecte ton compte Are.na pour utiliser tes channels, même privés.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Se connecter à Are.na") { Task { await account.connect() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Utiliser un token personnel") { app.sidebarItem = .account }
                    .buttonStyle(.link)
                Text("Sans compte, les channels publics marchent aussi : colle leur lien dans le champ en bas de la barre latérale.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            if let error = errors.message {
                Text(error).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: 420)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
