import ArenaKit
import SwiftUI

/// What the library window shows: a list of images, or one page of settings.
enum SidebarItem: Hashable {
    case images(LibrarySelection)
    case discover, playback, account
}

/// The two main places (every image, Découvrir), the user's channels (paused ones last and
/// dimmed), and the settings.
struct SidebarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    @Binding var item: SidebarItem
    @State private var deleting: String?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<SidebarItem?>(get: { item }, set: { item = $0 ?? .images(.all) })) {
                Section {
                    Label {
                        HStack {
                            Text("Toutes les images")
                            Spacer()
                            Text(verbatim: "\(blocks(for: .all, in: library.config).count)").foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "square.grid.2x2") }
                    .tag(SidebarItem.images(.all))
                    Label("Découvrir", systemImage: "safari").tag(SidebarItem.discover)
                }
                Section {
                    // Active channels first, paused ones after, each group in the user's order,
                    // which a drag changes inside the group.
                    let active = library.config.channels.filter(\.enabled)
                    let paused = library.config.channels.filter { !$0.enabled }
                    ForEach(active, id: \.slug, content: row)
                        .onMove { move(in: active, from: $0, to: $1) { $0 + paused.map(\.slug) } }
                    ForEach(paused, id: \.slug, content: row)
                        .onMove { move(in: paused, from: $0, to: $1) { active.map(\.slug) + $0 } }
                } header: {
                    HStack(spacing: 6) {
                        Text("Mes channels")
                        Spacer()
                        RefreshButton()
                        Button { item = .discover } label: { Image(systemName: "plus") }
                            .buttonStyle(.borderless)
                            .help(Text("Ajouter un channel"))
                            .accessibilityLabel(Text("Ajouter un channel"))
                    }
                    .padding(.trailing, 8)
                }
                Section("Réglages") {
                    Label("Lecture", systemImage: "play.rectangle").tag(SidebarItem.playback)
                    Label("Compte", systemImage: "person.crop.circle").tag(SidebarItem.account)
                }
            }
            // The Découvrir page shows its errors next to its field.
            if item != .discover, let error = errors.message {
                Text(error).font(.caption).foregroundStyle(.red).padding(10)
            }
        }
        .confirmChannelDeletion($deleting) { slug in
            if item == .images(.channel(slug)) { item = .images(.all) }
        }
    }

    /// One channel: a full dot when it feeds the playback, an empty one when paused (a click
    /// on the dot switches).
    private func row(_ channel: Channel) -> some View {
        HStack {
            Button { setEnabled(channel, !channel.enabled) } label: {
                Image(systemName: channel.enabled ? "circle.fill" : "circle")
                    .font(.system(size: 7))
                    .foregroundStyle(channel.enabled ? Color.green : Color.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(channel.enabled ? Text("Exclure de la lecture : ses images ne passent plus") : Text("Inclure dans la lecture : ses images repassent"))
            .accessibilityHidden(true)
            Text(verbatim: channel.slug).lineLimit(1)
                .foregroundStyle(channel.enabled ? .primary : .secondary)
            Spacer()
            // The images kept in the playback, like the grid shows them.
            Text(verbatim: "\(blocks(for: .channel(channel.slug), in: library.config).count)" + (channel.nextPage != nil ? "+" : ""))
                .foregroundStyle(.secondary)
        }
        .tag(SidebarItem.images(.channel(channel.slug)))
        .accessibilityElement(children: .combine)
        // The dimmed text and empty dot say it to the eye; VoiceOver hears it here.
        .accessibilityValue(channel.enabled ? Text(verbatim: "") : Text("Hors lecture"))
        .accessibilityAction(named: channel.enabled ? Text("Exclure de la lecture") : Text("Inclure dans la lecture")) { setEnabled(channel, !channel.enabled) }
        .contextMenu {
            Button(channel.enabled ? "Exclure de la lecture" : "Inclure dans la lecture") { setEnabled(channel, !channel.enabled) }
            Divider()
            // "Supprimer", not "Retirer": that word is for images taken out of the playback.
            Button("Supprimer le channel…") { deleting = channel.slug }
        }
    }

    private func move(in group: [Channel], from source: IndexSet, to destination: Int, order: ([String]) -> [String]) {
        var slugs = group.map(\.slug)
        slugs.move(fromOffsets: source, toOffset: destination)
        let all = order(slugs)
        Task { await library.reorder(all) }
    }

    private func setEnabled(_ channel: Channel, _ enabled: Bool) {
        Task { await library.setEnabled(channel.slug, enabled) }
    }
}

extension View {
    /// Asks before deleting the channel `slug` names (nil: no question); `before` runs just
    /// before the deletion, to leave a page that shows the channel.
    func confirmChannelDeletion(_ slug: Binding<String?>, before: @escaping (String) -> Void = { _ in }) -> some View {
        modifier(ChannelDeletion(slug: slug, before: before))
    }
}

private struct ChannelDeletion: ViewModifier {
    @Environment(LibraryStore.self) private var library
    @Binding var slug: String?
    let before: (String) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text("Supprimer « \(slug ?? "") » ?"),
            isPresented: Binding(get: { slug != nil }, set: { if !$0 { slug = nil } }),
            presenting: slug
        ) { slug in
            Button("Supprimer", role: .destructive) {
                before(slug)
                Task { await library.removeChannel(slug) }
            }
        } message: { _ in
            Text("Le channel quitte ta bibliothèque et la lecture, et ses images téléchargées sont effacées de ce Mac. Rien n'est supprimé sur Are.na : tu pourras le rajouter depuis Découvrir.")
        }
    }
}

/// Refreshes every channel: a spinner while it runs, and when it last happened.
private struct RefreshButton: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: 4) {
            if library.isRefreshing {
                Text("Actualisation…").font(.caption).foregroundStyle(.secondary)
                ProgressView().controlSize(.mini)
            } else {
                if let date = library.lastRefresh {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text(date, format: .relative(presentation: .named)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button { Task { await library.refresh(force: true) } } label: {
                    Image(systemName: "arrow.clockwise").font(.caption.weight(.semibold))
                        .frame(width: 20, height: 20)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help(Text("Actualiser les channels"))
                .accessibilityLabel(Text("Actualiser les channels"))
            }
        }
        .textCase(nil)
    }
}
