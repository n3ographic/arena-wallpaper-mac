import SwiftUI

/// Shown once at the top of the library: the app lives in the menu bar, and closing the
/// window does not quit it.
struct MenuBarHint: View {
    static let seenKey = "menuBarHintSeen"
    @AppStorage(MenuBarHint.seenKey) private var seen = false

    var body: some View {
        if !seen {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arena Wallpaper vit dans la barre des menus").font(.headline)
                    Text("Clique sur son icône, en haut à droite de l'écran, pour changer d'image ou mettre en pause. Fermer cette fenêtre ne quitte pas l'app.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Compris") { seen = true }
            }
            .padding(12)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
        }
    }
}
