import SwiftUI
import ArenaKit

struct GridView: View {
    @EnvironmentObject private var model: AppModel
    let channel: Channel

    private var blocks: [Block] { channel.blocks }

    var body: some View {
        ScrollView {
            if blocks.isEmpty {
                Text("Ce channel ne contient aucune image.").foregroundStyle(.secondary).padding()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(blocks, id: \.id) { block in
                    ThumbnailView(block: block, excluded: model.isExcluded(block.id))
                        .onTapGesture { Task { await model.apply(block) } }
                        .accessibilityAddTraits(.isButton)
                        .contextMenu { menu(for: block) }
                }
            }
            .padding()
            if channel.nextPage != nil {
                Button("Charger plus") { Task { await model.loadMore(channel.slug) } }
                    .disabled(model.loadingSlugs.contains(channel.slug))
                    .padding(.bottom)
            }
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
        Button(model.isExcluded(block.id) ? String(localized: "Remettre dans la rotation") : String(localized: "Retirer de la rotation")) {
            Task { await model.toggleExcluded([block.id]) }
        }
        Button("Ouvrir sur Are.na") { model.openOnArena(block.id) }
    }
}

/// A square cell; a GIF shows its first frame and a badge, and plays while hovered (unless
/// Reduce Motion is on); a removed image is dimmed.
struct ThumbnailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let block: Block
    var excluded = false
    @State private var image: NSImage?
    @State private var hovering = false
    @State private var playing: NSImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let playing {
                    AnimatedGIF(image: playing).opacity(excluded ? 0.35 : 1)
                } else if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                        .opacity(excluded ? 0.35 : 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomLeading) {
                if excluded {
                    Text("Retirée")
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
            .accessibilityLabel(Text(verbatim: block.title ?? String(localized: "Image sans titre")) + Text(excluded ? ", retirée" : ""))
            .task(id: block.id) { image = await Thumbnails.shared.image(for: block) }
            .onHover { hovering = $0 }
            .task(id: hovering) { await play() }
    }

    /// The original plays (Are.na's resized GIFs are often still); it is downloaded into the
    /// image cache on the first hover and then also serves as the wallpaper.
    private func play() async {
        guard hovering, block.isGIF, !reduceMotion else {
            playing = nil
            return
        }
        guard let url = try? await model.cache.original(for: block),
              let gif = NSImage(contentsOf: url), gif.size.width > 0, gif.size.height > 0,
              !Task.isCancelled, hovering else { return }
        playing = gif
    }
}

/// An animated GIF scaled to fill its frame (the cell clips it), never taking the clicks.
private struct AnimatedGIF: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            let scale = max(geometry.size.width / image.size.width, geometry.size.height / image.size.height)
            GIFImageView(image: image)
                .frame(width: image.size.width * scale, height: image.size.height * scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

private struct GIFImageView: NSViewRepresentable {
    let image: NSImage

    final class PassThroughImageView: NSImageView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSImageView {
        let view = PassThroughImageView()
        view.imageScaling = .scaleAxesIndependently
        view.animates = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = image
    }
}
