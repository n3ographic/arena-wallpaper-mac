import AppKit
import ArenaKit
import SwiftUI

/// The library window: sidebar, screen bar and grid, action bar.
struct LibraryView: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @State private var selection: LibrarySelection = .all
    @State private var selectedID: Int?

    private var shown: [Block] { blocks(for: selection, in: library.config) }
    private var selectedBlock: Block? { shown.first { $0.id == selectedID } }
    private var channel: Channel? {
        guard case .channel(let slug) = selection else { return nil }
        return library.config.channels.first { $0.slug == slug }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            VStack(spacing: 0) {
                ScreenBar()
                Divider()
                LibraryGridView(blocks: shown, channel: channel, selected: $selectedID)
                Divider()
                ActionBar(block: selectedBlock)
            }
        }
        .toolbar {
            ToolbarItem {
                Button { Task { await library.refresh(force: true) } } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
            }
        }
        .onChange(of: selection) { selectedID = nil }
        // Space pauses or resumes, right arrow shows the next image (text fields keep their keys),
        // Escape closes the window.
        .onKeyPress(.space) {
            Task { await playback.togglePause() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            Task { await playback.next() }
            return .handled
        }
        .onExitCommand { NSApp.keyWindow?.close() }
    }
}
