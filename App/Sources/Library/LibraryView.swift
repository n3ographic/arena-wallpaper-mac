import AppKit
import ArenaKit
import SwiftUI

/// The library window: sidebar, screen bar and grid, action bar; or the general settings.
struct LibraryView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    @State private var selectedID: Int?
    /// A text field has the keyboard: space and arrows belong to it, not to the playback.
    private var isTyping: Bool { NSApp.keyWindow?.firstResponder is NSTextView }
    @State private var scrollTarget: Int?
    /// The grid filter: every image of the selection, or only those taken out of the playback.
    @State private var removedOnly = false
    /// Opened by a click on an image, not when the selection follows the playback.
    @State private var inspecting = false
    @State private var columns = 1
    @FocusState private var focused: Bool

    private var item: SidebarItem { app.sidebarItem }
    private var inspected: Block? { selectedID.flatMap(library.block) }
    private var selection: LibrarySelection {
        if case .images(let selection) = item { return selection }
        return .all
    }
    private var shown: [Block] { blocks(for: selection, in: library.config, removedOnly: removedOnly) }
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

    /// The selection's name and the "Toutes / Retirées" filter above the grid.
    private var filterBar: some View {
        HStack {
            Text(verbatim: channel?.slug ?? String(localized: "Toutes les images")).font(.headline)
            Spacer()
            Picker("Afficher", selection: $removedOnly) {
                Text("Toutes").tag(false)
                Text("Retirées").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    var body: some View {
        // Computed once per update: the list can hold thousands of images.
        let shown = self.shown
        return NavigationSplitView {
            SidebarView(item: Binding(get: { app.sidebarItem }, set: { app.sidebarItem = $0 }))
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            switch item {
            case .playback:
                RotationView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .account:
                AccountView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .discover:
                DiscoverView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .images where library.config.channels.isEmpty:
                WelcomeView()
            case .images:
                VStack(spacing: 0) {
                    ScreenBar()
                    Divider()
                    filterBar
                    LibraryGridView(blocks: shown, channel: channel, selected: $selectedID, scrollTarget: $scrollTarget, onPick: { inspecting = true }, columns: $columns)
                    PlaybackBar()
                }
                .inspector(isPresented: Binding(get: { inspecting && inspected != nil }, set: { inspecting = $0 })) {
                    if let inspected {
                        ImageInspector(block: inspected) { inspecting = false }
                            .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                    }
                }
            }
        }
        .onChange(of: item) { selectedID = nil; inspecting = false }
        // "Afficher dans la bibliothèque" from the menu bar: select, scroll to and inspect the image.
        .task(id: app.reveal) {
            guard let id = app.reveal else { return }
            app.reveal = nil
            selectedID = id
            scrollTarget = id
            inspecting = true
        }
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
        // Return poses the selected image on the targeted screen(s).
        .onKeyPress(.return) {
            guard !isTyping, case .images = item, let inspected else { return .ignored }
            Task { await app.apply(inspected) }
            return .handled
        }
        // The arrows move the selection in the grid, like the Finder; with Command, left and right
        // go to the previous or next image of the playback.
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            guard !isTyping else { return .ignored }
            if press.modifiers.contains(.command) {
                switch press.key {
                case .leftArrow: Task { await playback.previous() }
                case .rightArrow: Task { await playback.next() }
                default: return .ignored
                }
                return .handled
            }
            switch press.key {
            case .upArrow: return moveSelection(by: -columns)
            case .downArrow: return moveSelection(by: columns)
            case .leftArrow: return moveSelection(by: -1)
            default: return moveSelection(by: 1)
            }
        }
        // Space pauses or resumes (text fields keep their keys).
        .onKeyPress(.space) {
            if isTyping { return .ignored }
            Task { await playback.togglePause() }
            return .handled
        }
        // Escape closes the inspector first, then the window.
        .onExitCommand { if inspecting { inspecting = false } else { NSApp.keyWindow?.close() } }
    }

    private func moveSelection(by step: Int) -> KeyPress.Result {
        guard !isTyping, case .images = item else { return .ignored }
        let shown = self.shown
        guard !shown.isEmpty else { return .ignored }
        let index = selectedID.flatMap { id in shown.firstIndex { $0.id == id } }
        let target = index.map { min(max($0 + step, 0), shown.count - 1) } ?? 0
        selectedID = shown[target].id
        scrollTarget = selectedID
        return .handled
    }
}
