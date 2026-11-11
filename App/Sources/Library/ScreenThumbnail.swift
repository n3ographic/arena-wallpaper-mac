import AppKit
import ArenaKit
import SwiftUI

/// An image of a block, loaded from its preview and decoded at most `maxPixels` wide.
struct BlockPreview: View {
    let block: Block?
    var maxPixels = 600
    @State private var image: NSImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .overlay {
                if let image { Image(nsImage: image).resizable().scaledToFill() }
            }
            .clipped()
            .task(id: block?.id) {
                image = nil
                guard let block, let (data, _) = try? await URLSession.shared.data(from: block.previewURL) else { return }
                image = Thumbnails.downscale(data, maxPixels: maxPixels)
            }
    }
}

/// One tile of the screen bar: the image on that screen, its name, and a state (target or not).
struct ScreenThumbnail: View {
    let name: String
    let block: Block?
    let aspectRatio: CGFloat
    let isTarget: Bool
    let action: () -> Void
    let openFraming: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                BlockPreview(block: block, maxPixels: 300)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isTarget ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isTarget ? 3 : 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityAddTraits(isTarget ? .isSelected : [])
            HStack(spacing: 2) {
                Text(verbatim: name).font(.caption).lineLimit(1)
                Button(action: openFraming) { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Cadrage de \(name)"))
            }
        }
    }
}
