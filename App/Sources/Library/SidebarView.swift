import ArenaKit
import SwiftUI

/// What the library window shows: a list of images, or one page of settings.
enum SidebarItem: Hashable {
    case images(LibrarySelection)
    case general, playback, account
}

/// "Général", the images, the channels (active and on hold), the preferences, and the field
/// to add a channel.
struct SidebarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    @Binding var item: SidebarItem
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<SidebarItem?>(get: { item }, set: { item = $0 ?? .images(.all) })) {
                Label("Général", systemImage: "gearshape").tag(SidebarItem.general)
                Section("Images") {
                    Label("Tout", systemImage: "square.grid.2x2").tag(SidebarItem.images(.all))
                    Label("Retirées", systemImage: "eye.slash").tag(SidebarItem.images(.removed))
                }
                Section {
                    ForEach(library.config.channels.filter(\.enabled), id: \.slug, content: row)
                } header: {
                    HStack(spacing: 6) {
                        Text("Channels actifs")
                        Spacer()
                        RefreshButton()
                    }
                }
                let onHold = library.config.channels.filter { !$0.enabled }
                if !onHold.isEmpty {
                    Section {
                        ForEach(onHold, id: \.slug, content: row)
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("En réserve")
                            Text("Visibles ici, jamais choisis automatiquement.").font(.caption2).textCase(nil)
                        }
                    }
                }
                Section("Préférences") {
                    Label("Lecture", systemImage: "play.rectangle").tag(SidebarItem.playback)
                    Label("Compte", systemImage: "person.crop.circle").tag(SidebarItem.account)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Lien ou slug du channel", text: $input).onSubmit(add)
                    Button("Ajouter", action: add)
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Tu es responsable du contenu des channels que tu ajoutes.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = errors.message {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(10)
        }
    }

    /// One channel: its check box moves it between "actifs" and "en réserve".
    private func row(_ channel: Channel) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { channel.enabled },
                set: { enabled in Task { await library.setEnabled(channel.slug, enabled) } }
            ))
            .labelsHidden()
            .help(Text("Utiliser dans la lecture"))
            .accessibilityLabel(Text("Utiliser \(channel.slug) dans la lecture"))
            Text(verbatim: channel.slug).lineLimit(1)
                .foregroundStyle(channel.enabled ? .primary : .secondary)
            Spacer()
            Text(verbatim: "\(channel.blocks.count)" + (channel.nextPage != nil ? "+" : ""))
                .foregroundStyle(.secondary)
        }
        .tag(SidebarItem.images(.channel(channel.slug)))
        .contextMenu {
            Button("Retirer") {
                if item == .images(.channel(channel.slug)) { item = .images(.all) }
                Task { await library.removeChannel(channel.slug) }
            }
        }
    }

    private func add() {
        let text = input
        Task {
            if await library.addChannel(text) {
                input = ""
                if let slug = parseChannelSlug(text) { item = .images(.channel(slug)) }
            }
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
