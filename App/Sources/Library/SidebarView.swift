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
                    // Active channels first, paused ones after, each group in the user's order.
                    let channels = library.config.channels.filter(\.enabled) + library.config.channels.filter { !$0.enabled }
                    ForEach(channels, id: \.slug, content: row)
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
            .help(channel.enabled ? Text("Mettre en pause : ses images ne passent plus dans la lecture") : Text("Reprendre : ses images repassent dans la lecture"))
            .accessibilityHidden(true)
            Text(verbatim: channel.slug).lineLimit(1)
                .foregroundStyle(channel.enabled ? .primary : .secondary)
            if !channel.enabled {
                Text("en pause").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: "\(channel.blocks.count)" + (channel.nextPage != nil ? "+" : ""))
                .foregroundStyle(.secondary)
        }
        .tag(SidebarItem.images(.channel(channel.slug)))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: channel.enabled ? Text("Mettre en pause") : Text("Reprendre")) { setEnabled(channel, !channel.enabled) }
        .contextMenu {
            Button(channel.enabled ? "Mettre en pause" : "Reprendre") { setEnabled(channel, !channel.enabled) }
            Divider()
            Button("Retirer") {
                if item == .images(.channel(channel.slug)) { item = .images(.all) }
                Task { await library.removeChannel(channel.slug) }
            }
        }
    }

    private func setEnabled(_ channel: Channel, _ enabled: Bool) {
        Task { await library.setEnabled(channel.slug, enabled) }
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
