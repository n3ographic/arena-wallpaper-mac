import ArenaKit
import SwiftUI

/// Bottom bar: the selected image and what can be done with it.
struct ActionBar: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    @Environment(PlaybackStore.self) private var playback
    let block: Block?

    var body: some View {
        VStack(spacing: 8) {
            playbackRow
            Divider()
            selectionRow
        }
        .padding(10)
        .background(.bar)
    }

    /// What plays: previous, pause, next, and when the next automatic change happens.
    private var playbackRow: some View {
        HStack(spacing: 8) {
            Button { Task { await playback.previous() } } label: { Label("Précédent", systemImage: "backward.end.fill") }
            Button { Task { await playback.togglePause() } } label: {
                Label(playback.nowPlaying.paused ? String(localized: "Reprendre") : String(localized: "Pause"),
                      systemImage: playback.nowPlaying.paused ? "play.fill" : "pause.fill")
            }
            Button { Task { await playback.next() } } label: { Label("Suivant", systemImage: "forward.end.fill") }
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(nextChangeText(playback.nowPlaying, now: context.date)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    /// The selected image and what can be done with it.
    private var selectionRow: some View {
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
