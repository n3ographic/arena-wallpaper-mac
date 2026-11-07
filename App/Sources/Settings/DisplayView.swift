import AppKit
import SwiftUI
import ArenaKit

struct DisplayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var positionX = 50.0
    @State private var positionY = 50.0

    var body: some View {
        Form {
            Picker("Écrans", selection: binding(\.screenMode)) {
                Text("Même image partout").tag(ScreenMode.same)
                Text("Une image par écran").tag(ScreenMode.perScreen)
                Text("Étalée sur tous les écrans").tag(ScreenMode.span)
            }
            Picker("Cadrage", selection: binding(\.fit)) {
                Text("Remplir").tag(Fit.fill)
                Text("Contenir").tag(Fit.contain)
                Text("Étirer").tag(Fit.stretch)
                Text("Centrer").tag(Fit.center)
            }
            Slider(value: $positionX, in: 0...100, step: 1) { Text("Position horizontale") } onEditingChanged: { editing in
                if !editing { save { $0.positionX = Int(positionX) } }
            }
            .disabled(model.config.fit == .stretch)
            Slider(value: $positionY, in: 0...100, step: 1) { Text("Position verticale") } onEditingChanged: { editing in
                if !editing { save { $0.positionY = Int(positionY) } }
            }
            .disabled(model.config.fit == .stretch)
            Picker("Fond des bandes", selection: backgroundKind) {
                Text("Flou").tag(false)
                Text("Couleur").tag(true)
            }
            .disabled(model.config.fit == .fill || model.config.fit == .stretch)
            if case .color(let hex) = model.config.background {
                ColorPicker("Couleur du fond", selection: Binding(
                    get: { Color(nsColor: NSColor(hex: hex)) },
                    set: { color in save { $0.background = .color(hex: NSColor(color).hexString) } }
                ), supportsOpacity: false)
            }
            Toggle("Adapter l'image à l'orientation de chaque écran", isOn: binding(\.matchOrientation))
                .disabled(model.config.screenMode != .perScreen)
        }
        .formStyle(.grouped)
        .onAppear {
            positionX = Double(model.config.positionX)
            positionY = Double(model.config.positionY)
        }
    }

    private func save(_ change: @escaping (inout Config) -> Void) {
        Task { await model.updateDisplay(change) }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(get: { model.config[keyPath: keyPath] }, set: { value in save { $0[keyPath: keyPath] = value } })
    }

    private var backgroundKind: Binding<Bool> {
        Binding(
            get: { if case .color = model.config.background { return true } else { return false } },
            set: { isColor in save { $0.background = isColor ? .color(hex: "#000000") : .blur } }
        )
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
