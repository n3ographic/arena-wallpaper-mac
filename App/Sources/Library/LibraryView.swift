import AppKit
import ArenaKit
import SwiftUI

/// The library window: sidebar, screen bar and grid, action bar; or the general settings.
struct LibraryView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    @State private var selection: LibrarySelection = .all
    @State private var selectedID: Int?
    @State private var scrollTarget: Int?
    @FocusState private var focused: Bool

    private var shown: [Block] { blocks(for: selection, in: library.config) }
    private var channel: Channel? {
        guard case .channel(let slug) = selection else { return nil }
        return library.config.channels.first { $0.slug == slug }
    }

    /// The image on the targeted screen (or the first one).
    private var currentID: Int? {
        let ids = playback.nowPlaying.ids
        if case .screen(let screenID) = display.target,
           let index = display.screens.firstIndex(where: { $0.id == screenID }), ids.indices.contains(index) {
            return ids[index]
        }
        return ids.first
    }

    var body: some View {
        // Computed once per update: the list can hold thousands of images.
        let shown = self.shown
        return NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if selection == .general {
                PreferencesView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScreenBar()
                    Divider()
                    LibraryGridView(blocks: shown, channel: channel, selected: $selectedID, scrollTarget: $scrollTarget)
                    Divider()
                    ActionBar(block: shown.first { $0.id == selectedID })
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(nextChangeText(playback.nowPlaying, now: context.date)).foregroundStyle(.secondary)
                }
                Button { Task { await playback.togglePause() } } label: {
                    Label(playback.nowPlaying.paused ? String(localized: "Reprendre") : String(localized: "Pause"),
                          systemImage: playback.nowPlaying.paused ? "play.fill" : "pause.fill")
                }
                Button { Task { await playback.previous() } } label: {
                    Label("Précédent", systemImage: "backward.end.fill")
                }
                Button { Task { await playback.next() } } label: {
                    Label("Suivant", systemImage: "forward.end.fill")
                }
                Button { Task { await library.refresh(force: true) } } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
            }
        }
        .onChange(of: selection) { selectedID = nil }
        // The blue selection follows the image on screen, and the grid scrolls to it.
        .onChange(of: currentID) {
            guard let id = currentID, shown.contains(where: { $0.id == id }) else { return }
            selectedID = id
            scrollTarget = id
        }
        // The keys below need the focus inside this window, not only the window itself.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        // Space pauses or resumes, right arrow shows the next image (text fields keep their keys),
        // Escape closes the window.
        .onKeyPress(.space) {
            Task { await playback.togglePause() }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            Task { await playback.previous() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            Task { await playback.next() }
            return .handled
        }
        .onExitCommand { NSApp.keyWindow?.close() }
    }
}
