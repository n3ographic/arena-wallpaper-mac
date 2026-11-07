import SwiftUI
import ArenaKit

struct GridView: View {
    let blocks: [Block]

    var body: some View {
        ScrollView {
            if blocks.isEmpty {
                Text("Ce channel ne contient aucune image.").foregroundStyle(.secondary).padding()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(blocks, id: \.id) { block in
                    ThumbnailView(block: block)
                }
            }
            .padding()
        }
    }
}

/// A square cell; a GIF shows its first frame and a badge.
struct ThumbnailView: View {
    let block: Block
    @State private var image: NSImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
            .accessibilityLabel(block.title ?? "Image sans titre")
            .task(id: block.id) { image = await Thumbnails.shared.image(for: block) }
    }
}
