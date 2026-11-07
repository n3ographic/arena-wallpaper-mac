import SwiftUI
import ArenaKit

struct GridView: View {
    @EnvironmentObject private var model: AppModel
    let blocks: [Block]

    var body: some View {
        ScrollView {
            if blocks.isEmpty {
                Text("Ce channel ne contient aucune image.").foregroundStyle(.secondary).padding()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(blocks, id: \.id) { block in
                    ThumbnailView(block: block, excluded: model.isExcluded(block.id), flagged: model.isFlagged(block.id))
                        .onTapGesture { Task { await model.apply(block) } }
                        .accessibilityAddTraits(.isButton)
                        .contextMenu { menu(for: block) }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func menu(for block: Block) -> some View {
        let screenCount = NSScreen.screens.count
        if model.config.screenMode == .perScreen && screenCount > 1 {
            ForEach(0..<screenCount, id: \.self) { index in
                Button("Écran \(index + 1)") { Task { await model.apply(block, onScreen: index) } }
            }
            Button("Tous les écrans") { Task { await model.apply(block) } }
        } else {
            Button("Appliquer") { Task { await model.apply(block) } }
        }
        Divider()
        Button(model.isExcluded(block.id) ? "Réinclure dans la rotation" : "Exclure de la rotation") {
            Task { await model.toggleExcluded([block.id]) }
        }
        if model.isFlagged(block.id) {
            Button("Garder cette image") { Task { await model.keepSensitive(block.id) } }
        }
        Button("Ouvrir sur Are.na") { model.openOnArena(block.id) }
    }
}

/// A square cell; a GIF shows its first frame and a badge; an excluded image is dimmed.
struct ThumbnailView: View {
    let block: Block
    var excluded = false
    var flagged = false
    @State private var image: NSImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                        .opacity(excluded ? 0.35 : 1)
                        .blur(radius: flagged ? 12 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomLeading) {
                if excluded || flagged {
                    Text(flagged ? "À vérifier" : "Exclue")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .background(.background, in: RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if block.isGIF {
                    Text("GIF")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel((block.title ?? "Image sans titre") + (flagged ? ", à vérifier" : excluded ? ", exclue" : ""))
            .task(id: block.id) { image = await Thumbnails.shared.image(for: block) }
    }
}
