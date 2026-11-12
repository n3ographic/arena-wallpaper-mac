import ArenaKit
import SwiftUI

/// The images of the selection. One click selects, a double click or Return poses.
struct LibraryGridView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    @State private var visible: Set<Int> = []
    let blocks: [Block]
    /// The channel whose next page the "Charger plus" button loads, if any.
    let channel: Channel?
    /// The selected images (several with Shift or Command).
    let selection: Set<Int>
    /// Set by the window when the image on screen changes: the grid scrolls to it.
    @Binding var scrollTarget: Int?
    /// A click on an image; the window reads the modifier keys and updates the selection.
    var onClick: (Int) -> Void = { _ in }
    /// Images per row, for the up and down arrows.
    @Binding var columns: Int
    /// The selection rectangle: called with nil and whether it adds to the selection when a
    /// drag starts, then with the images it covers, in grid order.
    var onMarquee: ([Int]?, Bool) -> Void = { _, _ in }
    var onClickOutside: () -> Void = {}

    private static let space = "grid"
    @State private var marquee: CGRect?
    /// Where each cell on screen is; a plain object, so a scroll does not redraw the grid.
    @State private var cells = CellFrames()
    final class CellFrames { var frames: [Int: CGRect] = [:] }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            if blocks.isEmpty {
                Text("Aucune image ici.").foregroundStyle(.secondary).padding()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(blocks, id: \.id) { block in
                    let isSelected = selection.contains(block.id)
                    ThumbnailView(block: block, excluded: library.isExcluded(block.id))
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: 3)
                            }
                        }
                        .onAppear { visible.insert(block.id) }
                        .onDisappear { visible.remove(block.id); cells.frames[block.id] = nil }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { cells.frames[block.id] = $0 }
                        // One gesture, so a single click is not held back waiting for a second
                        // one; the event's click count tells a double click.
                        .onTapGesture {
                            if NSApp.currentEvent?.clickCount == 2 { Task { await app.apply(block) } } else { onClick(block.id) }
                        }
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        .contextMenu { menu(for: block) }
                }
            }
            // Less at the top: the filter bar above already leaves 10 pt.
            .padding([.horizontal, .bottom])
            .padding(.top, 6)
            // A drag draws a selection rectangle, like on the desktop; a click still selects.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
                    .onChanged { drag in
                        let rect = CGRect(origin: drag.startLocation, size: .zero).union(CGRect(origin: drag.location, size: .zero))
                        if marquee == nil {
                            // Command or Shift adds to the selection, as in the Finder.
                            let flags = NSApp.currentEvent?.modifierFlags ?? []
                            onMarquee(nil, !flags.isDisjoint(with: [.command, .shift]))
                        }
                        marquee = rect
                        // Only the cells on screen have a frame: enough, the rectangle is on screen too.
                        let hits = blocks.lazy.map(\.id).filter { id in cells.frames[id]?.intersects(rect) == true }
                        onMarquee(Array(hits), false)
                    }
                    .onEnded { _ in marquee = nil }
            )
            .overlay(alignment: .topLeading) {
                if let marquee {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.12))
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1)
                        .frame(width: marquee.width, height: marquee.height)
                        .offset(x: marquee.minX, y: marquee.minY)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: Self.space)
            .background {
                // Same rule as the adaptive grid: 120 pt cells, 8 pt apart, 16 pt padding.
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.size.width, initial: true) { _, width in
                        columns = max(1, Int((width - 32 + 8) / 128))
                    }
                }
            }
            if let channel, channel.nextPage != nil {
                Button("Charger plus") { Task { await library.loadMore(channel.slug) } }
                    .disabled(library.loadingSlugs.contains(channel.slug))
                    .padding(.bottom)
            }
        }
        // A click on empty space (between or under the images) clears the selection; a click on
        // an image goes to the image's own gesture first.
        .contentShape(Rectangle())
        .onTapGesture { onClickOutside() }
        .onChange(of: scrollTarget) {
            guard let id = scrollTarget else { return }
            // Scrolling a long lazy grid is costly: only when the image is not already visible.
            if !visible.contains(id) { proxy.scrollTo(id, anchor: .center) }
            scrollTarget = nil
        }
        }
    }

    @ViewBuilder
    private func menu(for block: Block) -> some View {
        // On an image of a multiple selection: only what works for several images.
        let ids = selection.contains(block.id) && selection.count > 1 ? Array(selection) : [block.id]
        if ids.count > 1 {
            Button(library.isExcluded(block.id)
                   ? String(localized: "Remettre les \(ids.count) images dans la lecture")
                   : String(localized: "Retirer les \(ids.count) images de la lecture")) {
                Task { await app.toggleExcluded(ids) }
            }
        } else {
            singleMenu(for: block)
        }
    }

    @ViewBuilder
    private func singleMenu(for block: Block) -> some View {
        if library.config.screenMode == .perScreen && display.screens.count > 1 {
            ForEach(Array(display.screens.enumerated()), id: \.element.id) { index, screen in
                Button("Écran \(index + 1)") { Task { await app.apply(block, to: .screen(screen.id)) } }
            }
            Button("Tous les écrans") { Task { await app.apply(block, to: .all) } }
        } else {
            Button("Appliquer") { Task { await app.apply(block, to: .all) } }
        }
        Divider()
        Button(library.isExcluded(block.id) ? String(localized: "Remettre dans la lecture") : String(localized: "Retirer de la lecture")) {
            Task { await app.toggleExcluded([block.id]) }
        }
        Button("Ouvrir sur Are.na") { library.openOnArena(block.id) }
    }
}

/// A square cell; a GIF shows its first frame and a badge, and plays while hovered (unless
/// Reduce Motion is on); a removed image is dimmed.
struct ThumbnailView: View {
    @Environment(LibraryStore.self) private var library
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
        guard let url = try? await library.cache.original(for: block),
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
