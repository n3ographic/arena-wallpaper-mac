import ArenaKit
import SwiftUI

/// The inspector for several images: a pile of the first three, the count, and the one action
/// that fits (the grid shows either kept or removed images, never both).
struct SelectionStack: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    let blocks: [Block]
    let cancel: () -> Void

    private var removed: Bool { blocks.allSatisfy { library.isExcluded($0.id) } }
    private static let angles: [Double] = [-8, 6, -2]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button(action: cancel) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help(Text("Annuler la sélection"))
                    .accessibilityLabel(Text("Annuler la sélection"))
            }
            ZStack {
                // The first image on top.
                ForEach(Array(blocks.prefix(3).enumerated().reversed()), id: \.element.id) { index, block in
                    PileCard(block: block).rotationEffect(.degrees(Self.angles[index]))
                }
            }
            .frame(height: 170)
            .accessibilityHidden(true)
            Text("\(blocks.count) images").font(.headline)
            Button {
                Task { await app.toggleExcluded(blocks.map(\.id)) }
            } label: {
                Text(removed ? String(localized: "Remettre dans la lecture") : String(localized: "Retirer de la lecture"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button(action: cancel) { Text("Annuler la sélection").frame(maxWidth: .infinity) }
                .buttonStyle(.borderless)
            Spacer()
        }
        .controlSize(.large)
        .padding(14)
    }
}

/// One image of the pile, whole, with a white border like a print.
private struct PileCard: View {
    let block: Block
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Color.secondary.opacity(0.2).aspectRatio(4 / 3, contentMode: .fit)
            }
        }
        .frame(maxWidth: 170, maxHeight: 130)
        .padding(4)
        .background(.white)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .task(id: block.id) { image = await Thumbnails.shared.image(for: block) }
    }
}

/// "12 images retirées · Annuler" for a few seconds after a removal or a return.
struct RemovalNoticeBar: View {
    @Environment(AppCoordinator.self) private var app

    var body: some View {
        if let notice = app.removalNotice {
            HStack(spacing: 10) {
                Text(notice.removed
                     ? String(localized: "\(notice.count) images retirées de la lecture")
                     : String(localized: "\(notice.count) images remises dans la lecture"))
                Button("Annuler") { app.undoManager.undo() }
                    .buttonStyle(.link)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 10)
            .task(id: notice.id) {
                try? await Task.sleep(for: .seconds(6))
                if app.removalNotice?.id == notice.id { app.removalNotice = nil }
            }
        }
    }
}
