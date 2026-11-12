import ArenaKit
import SwiftUI

/// The selected image: a large preview, where it comes from, and what can be done with it.
struct ImageInspector: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    let block: Block
    let close: () -> Void

    private var channels: [String] {
        library.config.channels.filter { $0.blocks.contains { $0.id == block.id } }.map(\.slug)
    }
    private var perScreen: Bool { library.config.screenMode == .perScreen && display.screens.count > 1 }
    /// Screen numbers (from 1) where the image would look soft.
    private var softOn: [Int] {
        display.screens.enumerated().filter { block.isLowResolution(for: [$0.element]) }.map { $0.offset + 1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .help(Text("Fermer"))
                        .accessibilityLabel(Text("Fermer"))
                }
                BlockPreview(block: block, maxPixels: 900)
                    .aspectRatio(aspect, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text(verbatim: block.title ?? String(localized: "Sans titre"))
                    .font(.headline).lineLimit(3).textSelection(.enabled)
                VStack(alignment: .leading, spacing: 3) {
                    if !channels.isEmpty {
                        Text(verbatim: channels.joined(separator: ", "))
                    }
                    if let w = block.width, let h = block.height {
                        Text(verbatim: "\(w) × \(h) px")
                    }
                    if library.isExcluded(block.id) {
                        Text("Retirée de la lecture")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if !softOn.isEmpty {
                    Label(softOn.count == display.screens.count
                          ? String(localized: "Petite pour tes écrans : elle sera un peu floue.")
                          : String(localized: "Petite pour l'écran \(softOn.map(String.init).joined(separator: ", ")) : elle sera un peu floue."),
                          systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                pose
                Button { Task { await app.toggleExcluded([block.id]) } } label: {
                    Text(library.isExcluded(block.id) ? String(localized: "Remettre dans la lecture") : String(localized: "Retirer de la lecture"))
                        .frame(maxWidth: .infinity)
                }
                Button { library.openOnArena(block.id) } label: {
                    Text("Ouvrir sur Are.na").frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .padding(14)
        }
    }

    private var aspect: CGFloat {
        guard let w = block.width, let h = block.height, w > 0, h > 0 else { return 1 }
        return CGFloat(w) / CGFloat(h)
    }

    /// One image per screen: a menu to choose where; otherwise a plain button.
    @ViewBuilder private var pose: some View {
        if perScreen {
            Menu {
                Button("Tous les écrans") { Task { await app.apply(block, to: .all) } }
                ForEach(Array(display.screens.enumerated()), id: \.element.id) { index, screen in
                    Button("Écran \(index + 1)") { Task { await app.apply(block, to: .screen(screen.id)) } }
                }
            } label: {
                Text("Poser sur…").frame(maxWidth: .infinity)
            }
            .menuStyle(.borderedButton)
            .frame(maxWidth: .infinity)
        } else {
            Button { Task { await app.apply(block, to: .all) } } label: {
                Text("Poser").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
