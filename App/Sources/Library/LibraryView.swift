import AppKit
import ArenaKit
import SwiftUI

/// The library window: sidebar, screen bar and grid, action bar; or the general settings.
struct LibraryView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    /// The selected images; `anchor` is where a Shift selection starts, `cursor` where the
    /// arrows move from.
    @State private var selection: Set<Int> = []
    @State private var anchor: Int?
    @State private var cursor: Int?
    /// The selection when a rectangle drag started (kept with Command or Shift).
    @State private var marqueeBase: Set<Int> = []
    /// A text field has the keyboard: space and arrows belong to it, not to the playback.
    private var isTyping: Bool { NSApp.keyWindow?.firstResponder is NSTextView }
    @State private var scrollTarget: Int?
    /// The grid filter: the kept images of the source, or only those taken out of the playback.
    @State private var removedOnly = false
    /// The inspector stays as the user leaves it: it never opens or closes by itself, so the grid
    /// does not reflow under the pointer (a click, a rectangle drag).
    @AppStorage("inspectorShown") private var inspectorShown = true
    @State private var columns = 1
    @State private var deleting: String?
    @FocusState private var focused: Bool

    private var item: SidebarItem { app.sidebarItem }
    /// One selected image has the detailed inspector; several have the pile.
    private var inspected: Block? { selection.count == 1 ? selection.first.flatMap(library.block) : nil }
    /// Where the grid's images come from: every channel or one.
    private var source: LibrarySelection {
        if case .images(let source) = item { return source }
        return .all
    }
    private var shown: [Block] { blocks(for: source, in: library.config, removed: removedOnly) }
    private var channel: Channel? {
        guard case .channel(let slug) = source else { return nil }
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

    /// The source's name with its playback switch, the "Gardées / Retirées" filter, and the
    /// channel's removal.
    private var filterBar: some View {
        HStack(spacing: 12) {
            Text(verbatim: channel?.slug ?? String(localized: "Toutes les images")).font(.headline)
            // The same switch as the sidebar dot and its menu, where the channel is in view.
            if let channel {
                Toggle("Dans la lecture", isOn: Binding(
                    get: { channel.enabled },
                    set: { enabled in Task { await library.setEnabled(channel.slug, enabled) } }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(Text("Désactivé, ses images ne passent plus dans la lecture"))
            }
            Spacer()
            Picker("Afficher", selection: $removedOnly) {
                Text("Gardées").tag(false)
                Text("Retirées").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if let channel {
                Button { deleting = channel.slug } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help(Text("Supprimer ce channel"))
                    .accessibilityLabel(Text("Supprimer ce channel"))
                    .confirmChannelDeletion($deleting) { _ in app.sidebarItem = .images(.all) }
            }
        }
        .padding(.horizontal, 16)
        // A margin under the bar, so the scrolled images stop short of it.
        .padding(.vertical, 10)
    }

    var body: some View {
        // Computed once per update: the list can hold thousands of images.
        let shown = self.shown
        return NavigationSplitView {
            SidebarView(item: Binding(get: { app.sidebarItem }, set: { app.sidebarItem = $0 }))
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            VStack(spacing: 0) {
                MenuBarHint()
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
                        LibraryGridView(blocks: shown, channel: channel, selection: selection, scrollTarget: $scrollTarget, onClick: click, columns: $columns, onMarquee: marquee, onClickOutside: clearSelection)
                            .overlay(alignment: .bottom) { RemovalNoticeBar() }
                        PlaybackBar()
                    }
                    .inspector(isPresented: $inspectorShown) {
                        Group {
                            if let inspected {
                                ImageInspector(block: inspected) { inspectorShown = false }
                            } else if selection.count > 1 {
                                SelectionStack(blocks: shown.filter { selection.contains($0.id) }, cancel: clearSelection)
                            } else {
                                ContentUnavailableView("Aucune sélection", systemImage: "photo.on.rectangle",
                                                       description: Text("Clique sur une image, ou glisse pour en sélectionner plusieurs."))
                            }
                        }
                        .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                    }
                    // In the window's toolbar, top right, as in the Finder and Photos.
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button { inspectorShown.toggle() } label: {
                                Label(inspectorShown ? "Masquer l'inspecteur" : "Afficher l'inspecteur", systemImage: "sidebar.right")
                            }
                            .help(inspectorShown ? Text("Masquer l'inspecteur") : Text("Afficher l'inspecteur"))
                        }
                    }
                }
            }
        }
        .onChange(of: item) { clearSelection() }
        // An image leaves the grid (removed, put back, other filter): it leaves the selection too.
        .onChange(of: shown.map(\.id)) { _, ids in selection.formIntersection(ids) }
        // "Afficher dans la bibliothèque" from the menu bar: select, scroll to and inspect the image.
        .task(id: app.reveal) {
            guard let id = app.reveal else { return }
            app.reveal = nil
            removedOnly = library.isExcluded(id)
            select(id)
            scrollTarget = id
            inspectorShown = true
        }
        // The blue selection follows the image on screen (unless several are selected), and the
        // grid scrolls to it.
        .onChange(of: currentID) {
            guard selection.count <= 1, let id = currentID, shown.contains(where: { $0.id == id }) else { return }
            select(id)
            scrollTarget = id
        }
        // ⌘A selects every image of the grid.
        .onChange(of: app.selectAllRequests) {
            guard case .images = item, !shown.isEmpty else { return }
            selection = Set(shown.map(\.id))
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
            // With Shift, the selection grows from the first selected image.
            let extend = press.modifiers.contains(.shift)
            switch press.key {
            case .upArrow: return moveSelection(by: -columns, extend: extend)
            case .downArrow: return moveSelection(by: columns, extend: extend)
            case .leftArrow: return moveSelection(by: -1, extend: extend)
            default: return moveSelection(by: 1, extend: extend)
            }
        }
        // Space pauses or resumes (text fields keep their keys).
        .onKeyPress(.space) {
            if isTyping { return .ignored }
            Task { await playback.togglePause() }
            return .handled
        }
        // Escape drops the selection first, then closes the window.
        .onExitCommand {
            if !selection.isEmpty { clearSelection() } else { NSApp.keyWindow?.close() }
        }
    }

    /// Like the Finder: a click selects one image, Command adds or takes one out, Shift
    /// selects every image from the first one clicked.
    private func click(_ id: Int) {
        // The keys held during this click, not at the time the code runs.
        let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.remove(id) == nil { selection.insert(id) }
            anchor = id
            cursor = id
        } else if flags.contains(.shift), let anchor {
            cursor = id
            selection = range(from: anchor, to: id)
        } else {
            select(id)
        }
    }

    /// A drag in the grid: the images under the rectangle, added to what was selected before
    /// when the drag started with Command or Shift.
    private func marquee(_ hits: [Int]?, _ additive: Bool) {
        guard let hits else {
            marqueeBase = additive ? selection : []
            return
        }
        selection = marqueeBase.union(hits)
        anchor = hits.first ?? anchor
        cursor = hits.last ?? cursor
    }

    private func select(_ id: Int) {
        selection = [id]
        anchor = id
        cursor = id
    }

    private func clearSelection() {
        selection = []
        anchor = nil
        cursor = nil
    }

    /// The images between two of the grid, both included.
    private func range(from start: Int, to end: Int) -> Set<Int> {
        let shown = self.shown
        guard let a = shown.firstIndex(where: { $0.id == start }), let b = shown.firstIndex(where: { $0.id == end }) else { return [end] }
        return Set(shown[min(a, b)...max(a, b)].map(\.id))
    }

    private func moveSelection(by step: Int, extend: Bool) -> KeyPress.Result {
        guard !isTyping, case .images = item else { return .ignored }
        let shown = self.shown
        guard !shown.isEmpty else { return .ignored }
        let index = cursor.flatMap { id in shown.firstIndex { $0.id == id } }
        let target = shown[index.map { min(max($0 + step, 0), shown.count - 1) } ?? 0].id
        if extend, let anchor {
            cursor = target
            selection = range(from: anchor, to: target)
        } else {
            select(target)
        }
        scrollTarget = target
        return .handled
    }
}
