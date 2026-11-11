import ArenaKit
import SwiftUI

/// "Tout", "Retirées", the channels, and the field to add one.
struct SidebarView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    @Binding var selection: LibrarySelection
    @State private var input = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<LibrarySelection?>(get: { selection }, set: { selection = $0 ?? .all })) {
                Label("Tout", systemImage: "square.grid.2x2").tag(LibrarySelection.all)
                Label("Retirées", systemImage: "eye.slash").tag(LibrarySelection.removed)
                Label("Général", systemImage: "gearshape").tag(LibrarySelection.general)
                Section {
                    ForEach(library.config.channels, id: \.slug) { channel in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { channel.enabled },
                                set: { enabled in Task { await library.setEnabled(channel.slug, enabled) } }
                            ))
                            .labelsHidden()
                            .accessibilityLabel(Text("Utiliser \(channel.slug) dans la rotation"))
                            Text(verbatim: channel.slug).lineLimit(1)
                            Spacer()
                            Text(verbatim: "\(channel.blocks.count)" + (channel.nextPage != nil ? "+" : ""))
                                .foregroundStyle(.secondary)
                        }
                        .tag(LibrarySelection.channel(channel.slug))
                        .contextMenu {
                            Button("Retirer") {
                                if selection == .channel(channel.slug) { selection = .all }
                                Task { await library.removeChannel(channel.slug) }
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Channels")
                        Spacer()
                        RefreshButton()
                    }
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

    private func add() {
        let text = input
        Task {
            if await library.addChannel(text) {
                input = ""
                if let slug = parseChannelSlug(text) { selection = .channel(slug) }
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
