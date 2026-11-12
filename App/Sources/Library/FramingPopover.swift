import AppKit
import ArenaKit
import SwiftUI

/// Framing of one screen (or of all, with a nil `screenID`), with a live preview of the image
/// that screen shows. Applied when a gesture ends; the preview never touches the wallpaper.
struct FramingPopover: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackStore.self) private var playback
    @Environment(DisplayStore.self) private var display
    let screenID: String?
    @State private var framing = Framing()
    @State private var source: CGImage?
    @State private var preview: NSImage?
    @State private var pendingApply: Task<Void, Never>?

    private var screenIndex: Int { screenID.flatMap { id in display.screens.firstIndex { $0.id == id } } ?? 0 }
    private var block: Block? {
        let ids = playback.nowPlaying.ids
        return (ids.indices.contains(screenIndex) ? ids[screenIndex] : ids.first).flatMap(library.block)
    }
    /// The screens the framing applies to.
    private var targetScreens: [Screen] {
        screenID == nil ? display.screens : display.screens.filter { $0.id == screenID }
    }
    private var canvas: CGSize {
        guard display.screens.indices.contains(screenIndex) else { return CGSize(width: 1600, height: 1000) }
        let frame = display.screens[screenIndex].frame
        return CGSize(width: frame.width, height: frame.height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.secondary.opacity(0.15)
                .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
                .overlay { if let preview { Image(nsImage: preview).resizable() } }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            if let block, block.isLowResolution(for: targetScreens) {
                Label("Image petite pour cet écran : elle sera un peu floue.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Cadrage", selection: Binding(get: { framing.fit }, set: { fit in framing.fit = fit; framing.positionX = 50; framing.positionY = 50; commit() })) {
                Text("Remplir").tag(Fit.fill)
                Text("Contenir").tag(Fit.contain)
                Text("Étirer").tag(Fit.stretch)
                Text("Centrer").tag(Fit.center)
            }
            Slider(value: position(\.positionX), in: 0...100, step: 1) { Text("Position horizontale") } onEditingChanged: { if !$0 { commit() } }
                .disabled(framing.fit == .stretch)
            Slider(value: position(\.positionY), in: 0...100, step: 1) { Text("Position verticale") } onEditingChanged: { if !$0 { commit() } }
                .disabled(framing.fit == .stretch)
            let bands = framing.fit == .contain || framing.fit == .center
            Picker("Fond des bandes", selection: Binding(
                get: { if case .color = framing.background { return true } else { return false } },
                set: { isColor in framing.background = isColor ? .color(hex: "#000000") : .blur; commit() }
            )) {
                Text("Flou").tag(false)
                Text("Couleur").tag(true)
            }
            .disabled(!bands)
            if case .color(let hex) = framing.background {
                ColorPicker("Couleur du fond", selection: Binding(
                    get: { Color(nsColor: NSColor(hex: hex)) },
                    set: { color in framing.background = .color(hex: NSColor(color).hexString); commitSoon() }
                ), supportsOpacity: false)
                .disabled(!bands)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            framing = screenID.map { library.config.framing(for: $0) } ?? library.config.defaultFraming
        }
        .task(id: block?.id) {
            source = nil
            guard let block, let data = try? await downloadImage(block.previewURL),
                  let image = Thumbnails.downscale(data, maxPixels: 600),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            source = cg
            redraw()
        }
        .onChange(of: framing) { redraw() }
    }

    private func position(_ keyPath: WritableKeyPath<Framing, Int>) -> Binding<Double> {
        Binding(get: { Double(framing[keyPath: keyPath]) }, set: { framing[keyPath: keyPath] = Int($0) })
    }

    /// The preview is at most 600 px wide, with the screen's ratio.
    private func redraw() {
        guard let source else { return }
        let width = 600.0, height = max(1, (600.0 * canvas.height / canvas.width).rounded())
        let image = Renderer.render(source, canvasSize: CGSize(width: width, height: height), framing: framing)
        preview = NSImage(cgImage: image, size: .zero)
    }

    private func commit() {
        pendingApply?.cancel()
        let value = framing
        Task { await display.setFraming(value, for: screenID) }
    }

    /// A color picker changes continuously: wait for it to settle.
    private func commitSoon() {
        pendingApply?.cancel()
        pendingApply = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { commit() }
        }
    }
}

extension NSColor {
    convenience init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        let color = usingColorSpace(.sRGB) ?? self
        let r = Int((color.redComponent * 255).rounded()), g = Int((color.greenComponent * 255).rounded()), b = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
