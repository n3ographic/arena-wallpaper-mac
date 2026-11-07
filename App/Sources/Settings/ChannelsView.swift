import SwiftUI
import ArenaKit

/// Channel list on the left, images of the selected channel on the right.
struct ChannelsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var input = ""
    @State private var selection: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Lien ou slug du channel", text: $input)
                    .onSubmit(add)
                Button("Ajouter", action: add)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Actualiser") { Task { await model.refresh() } }
            }
            .padding()
            if let error = model.lastError {
                Text(error).foregroundStyle(.red).padding(.horizontal)
            }
            HStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(model.config.channels, id: \.slug) { channel in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { channel.enabled },
                                set: { enabled in Task { await model.setEnabled(channel.slug, enabled) } }
                            ))
                            .labelsHidden()
                            .accessibilityLabel("Utiliser \(channel.slug) dans la rotation")
                            Text(channel.slug)
                            Spacer()
                            Text("\(channel.blocks.count)").foregroundStyle(.secondary)
                        }
                        .tag(channel.slug)
                        .contextMenu {
                            Button("Retirer") { Task { await model.removeChannel(channel.slug) } }
                        }
                    }
                }
                .frame(width: 240)
                Divider()
                if let channel = model.config.channels.first(where: { $0.slug == selection }) {
                    GridView(blocks: channel.blocks) { block in Task { await model.apply(block) } }
                } else {
                    Text("Choisis un channel pour voir ses images.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func add() {
        let text = input
        Task {
            if await model.addChannel(text) {
                input = ""
                selection = parseChannelSlug(text)
            }
        }
    }
}
