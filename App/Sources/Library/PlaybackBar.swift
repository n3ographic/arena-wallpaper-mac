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

    /// What plays: the image on screen, previous / pause / next, and the time to the next change.
    private var playbackRow: some View {
        let ids = playback.nowPlaying.ids
        let current = ids.first.flatMap(library.block)
        return HStack(spacing: 16) {
            HStack(spacing: 10) {
                BlockPreview(block: current, maxPixels: 120)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: current.map { shortenedTitle($0.title ?? String(localized: "Sans titre"), max: 32) } ?? String(localized: "Aucune image affichée"))
                        .font(.callout.weight(.medium)).lineLimit(1)
                    Text("À l'écran").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                Button { Task { await playback.previous() } } label: {
                    Image(systemName: "backward.fill").font(.title3)
                }
                .help(Text("Précédent"))
                .accessibilityLabel(Text("Précédent"))
                Button { Task { await playback.togglePause() } } label: {
                    Image(systemName: playback.nowPlaying.paused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor, in: Circle())
                }
                .help(playback.nowPlaying.paused ? Text("Reprendre") : Text("Pause"))
                .accessibilityLabel(playback.nowPlaying.paused ? Text("Reprendre") : Text("Pause"))
                Button { Task { await playback.next() } } label: {
                    Image(systemName: "forward.fill").font(.title3)
                }
                .help(Text("Suivant"))
                .accessibilityLabel(Text("Suivant"))
            }
            .buttonStyle(.plain)

            TimelineView(.periodic(from: .now, by: 15)) { context in
                VStack(alignment: .trailing, spacing: 4) {
                    Text(nextChangeText(playback.nowPlaying, now: context.date))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    ProgressView(value: playback.nowPlaying.nextChange.map {
                        progress(nextChange: $0, intervalMinutes: library.config.intervalMinutes, now: context.date)
                    } ?? 0)
                    .frame(width: 160)
                    .opacity(playback.nowPlaying.paused ? 0.35 : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
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
                Button(library.isExcluded(block.id) ? String(localized: "Remettre dans la lecture") : String(localized: "Retirer")) {
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
