import ArenaKit
import SwiftUI

/// The Are.na account, the library at a glance, the app's language and disk space.
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    @State private var showsTokenField = false
    @State private var token = ""

    var body: some View {
        Form {
            if account.isConnected {
                profileSection
                Section("Connexion") {
                    LabeledContent("Méthode") { Text(methodText) }
                    if let since = account.connectedSince {
                        LabeledContent("Depuis") { Text(since, format: .dateTime.day().month(.wide).year()) }
                    }
                    Button("Se déconnecter", role: .destructive) { account.disconnect() }
                }
            } else {
                Section("Connexion") {
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
            }
            librarySection
            LanguageSection()
            StorageSection()
            if let error = errors.message {
                Text(error).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .task(id: account.isConnected) { await account.loadProfile() }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section("Profil Are.na") {
            if let profile = account.profile {
                HStack(spacing: 12) {
                    AsyncImage(url: profile.avatar) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Text(verbatim: profile.initials).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.quaternary)
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: profile.name).font(.headline)
                        Text(verbatim: "@\(profile.slug)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link("Voir sur Are.na", destination: profile.profileURL)
                }
                LabeledContent("Channels") { Text(profile.channels, format: .number) }
                LabeledContent("Abonnés") { Text(profile.followers, format: .number) }
                LabeledContent("Abonnements") { Text(profile.following, format: .number) }
                if let since = profile.memberSince {
                    LabeledContent("Membre depuis") { Text(since, format: .dateTime.month(.wide).year()) }
                }
            } else if account.isLoadingProfile {
                HStack { ProgressView().controlSize(.small); Text("Chargement du profil…").foregroundStyle(.secondary) }
            } else {
                Text("Profil indisponible.").foregroundStyle(.secondary)
            }
        }
    }

    private var librarySection: some View {
        let channels = library.config.channels
        let active = channels.filter(\.enabled)
        let images = Set(channels.flatMap(\.blocks).map(\.id))
        return Section("Bibliothèque") {
            LabeledContent("Channels actifs") { Text(active.count, format: .number) }
            LabeledContent("Channels en réserve") { Text(channels.count - active.count, format: .number) }
            LabeledContent("Images chargées") { Text(images.count, format: .number) }
            LabeledContent("Images retirées") { Text(library.config.excluded.count, format: .number) }
            if let date = library.lastRefresh {
                LabeledContent("Dernière actualisation") { Text(date, format: .relative(presentation: .named)) }
            }
        }
    }

    private var methodText: String {
        switch account.method {
        case .oauth: return String(localized: "Connexion Are.na")
        case .personalToken: return String(localized: "Token personnel")
        case nil: return String(localized: "Connecté")
        }
    }
}
