import ArenaKit
import SwiftUI

/// "Tous" plus one tile per screen. In "one image per screen" mode a click aims the next
/// pose at that screen (a second click opens its framing); in the other modes a click opens
/// the framing at once and the target stays "Tous".
struct ScreenBar: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackStore.self) private var playback
    @Environment(DisplayStore.self) private var display
    /// Which framing popover is open: "all" or a screen id.
    @State private var openFraming: String?

    private var perScreen: Bool { library.config.screenMode == .perScreen && display.screens.count > 1 }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            tile(key: "all", name: String(localized: "Tous"), index: 0, isTarget: display.target == .all, screenID: nil)
            if display.screens.count > 1 {
                Divider().frame(height: 80)
                ForEach(Array(display.screens.enumerated()), id: \.element.id) { index, screen in
                    tile(key: screen.id, name: String(localized: "Écran \(index + 1)"), index: index,
                         isTarget: display.target == .screen(screen.id), screenID: screen.id)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
    }

    private func tile(key: String, name: String, index: Int, isTarget: Bool, screenID: String?) -> some View {
        let frame = display.screens.indices.contains(index) ? display.screens[index].frame : nil
        let ratio = frame.map { CGFloat($0.width) / CGFloat(max(1, $0.height)) } ?? 16.0 / 10.0
        // In span mode only the framing of "Tous" exists, whichever tile is clicked.
        let framingKey = library.config.screenMode == .span ? "all" : key
        return ScreenThumbnail(
            name: name, block: block(at: screenID == nil ? 0 : index), aspectRatio: ratio, isTarget: isTarget,
            action: {
                guard perScreen else { openFraming = framingKey; return }
                if isTarget { openFraming = framingKey } else {
                    Task { await display.setTarget(screenID.map { .screen($0) } ?? .all) }
                }
            },
            openFraming: { openFraming = framingKey }
        )
        .popover(isPresented: Binding(get: { openFraming == key }, set: { if !$0 { openFraming = nil } })) {
            FramingPopover(screenID: framingKey == "all" ? nil : framingKey)
        }
    }

    private func block(at index: Int) -> Block? {
        let ids = playback.nowPlaying.ids
        return (ids.indices.contains(index) ? ids[index] : ids.first).flatMap(library.block)
    }
}
