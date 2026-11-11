import ArenaKit
import SwiftUI

/// Bottom bar: the selected image and what can be done with it.
struct ActionBar: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    let block: Block?

    var body: some View {
        HStack(spacing: 12) {
            if let block {
                Text(verbatim: shortenedTitle(block.title ?? String(localized: "Sans titre"), max: 40))
                    .lineLimit(1).foregroundStyle(.secondary)
                Spacer()
                Button(poseLabel) { Task { await app.apply(block) } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                Button(library.isExcluded(block.id) ? String(localized: "Remettre dans la rotation") : String(localized: "Retirer")) {
                    Task { await app.toggleExcluded([block.id]) }
                }
                Button("Ouvrir sur Are.na") { library.openOnArena(block.id) }
            } else {
                Text("Sélectionne une image.").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(10)
        .background(.bar)
    }

    private var poseLabel: String {
        switch display.target {
        case .all:
            return display.screens.count > 1 ? String(localized: "Poser sur tous les écrans") : String(localized: "Poser")
        case .screen(let id):
            let number = (display.screens.firstIndex { $0.id == id } ?? 0) + 1
            return String(localized: "Poser sur l'écran \(number)")
        }
    }
}
