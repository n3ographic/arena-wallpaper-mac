import SwiftUI

/// Content of the menu bar popover (filled in by later tasks).
struct PanelView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aucune image affichée")
                .font(.headline)
            Button("Réglages", action: openSettings)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}
