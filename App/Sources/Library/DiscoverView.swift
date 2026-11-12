import ArenaKit
import SwiftUI

/// Adding channels: one field to search Are.na (Premium accounts) or paste a link or slug,
/// then the search results or the channels the user follows, as cards.
struct DiscoverView: View {
    @Environment(AccountStore.self) private var account
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    @State private var input = ""
    @State private var followed: [ChannelSuggestion]?
    @State private var found: [ChannelSuggestion]?
    @State private var searchMessage: String?
    @FocusState private var fieldFocused: Bool

    private var text: String { input.trimmingCharacters(in: .whitespaces) }
    /// A link has a dot or a slash; anything else is a search (and may also be a slug).
    private var isLink: Bool { text.contains("/") || text.contains(".") }
    private var slug: String? { parseChannelSlug(text) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                field
                // A plain word is a search when signed in: the direct add is for links (or slugs when signed out).
                if !text.isEmpty, let slug, isLink || !account.isConnected {
                    HStack {
                        Text("Ajouter le channel « \(slug) »")
                        Spacer()
                        Button("Ajouter") { add(slug) }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                // Next to the field and the buttons that cause it, not under a long list of results.
                if let error = errors.message {
                    Text(error).foregroundStyle(.red)
                }
                if text.isEmpty {
                    section(title: "Tes abonnements", channels: followed, empty: "Aucun nouveau channel suivi.")
                } else if !isLink {
                    if let searchMessage {
                        Text(searchMessage).foregroundStyle(.secondary)
                    } else {
                        section(title: "Résultats", channels: found, empty: "Aucun résultat.")
                    }
                }
                Text("Tu es responsable du contenu des channels que tu ajoutes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { fieldFocused = true }
        .task(id: account.isConnected) {
            followed = account.isConnected ? await account.followedChannels() : nil
        }
        .task(id: text) { await search() }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(account.isConnected ? "Rechercher, ou coller un lien Are.na" : "Coller le lien ou le slug d'un channel", text: $input)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { if let slug, isLink || !account.isConnected { add(slug) } }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Cards of the channels not in the library yet; a spinner while loading.
    @ViewBuilder
    private func section(title: LocalizedStringKey, channels: [ChannelSuggestion]?, empty: LocalizedStringKey) -> some View {
        if account.isConnected {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                if let channels {
                    let added = Set(library.config.channels.map(\.slug))
                    let fresh = channels.filter { !added.contains($0.slug) }
                    if fresh.isEmpty {
                        Text(empty).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                            ForEach(fresh) { card($0) }
                        }
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
        } else if text.isEmpty {
            Text("Connecte-toi à Are.na (page Compte) pour voir tes abonnements et chercher des channels.")
                .foregroundStyle(.secondary)
        }
    }

    private func card(_ channel: ChannelSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: channel.title).font(.body.weight(.medium)).lineLimit(2)
            Text(verbatim: [channel.owner, channel.blocks.map { "\($0)" }].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Button("Ajouter") { add(channel.slug) }
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        .accessibilityElement(children: .combine)
    }

    /// Stays on this page, so several channels can be added in a row.
    private func add(_ slug: String) {
        Task {
            if await library.addChannel(slug), slug == self.slug { input = "" }
        }
    }

    /// Waits for a pause in typing (the next keystroke cancels this task).
    private func search() async {
        found = nil
        searchMessage = nil
        guard account.isConnected, !text.isEmpty, !isLink else { return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        do {
            found = try await account.searchChannels(text)
        } catch ArenaError.forbidden {
            searchMessage = String(localized: "La recherche Are.na demande un compte Premium. Tu peux toujours coller un lien.")
        } catch {
            searchMessage = String(localized: "Recherche impossible pour le moment.")
        }
    }
}
