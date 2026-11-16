import ArenaKit
import SwiftUI

/// Bottom bar, like a music player: a thin progress line on top, what is on screen (one
/// thumbnail per screen) on the left, the controls in the exact center, the time left on the right.
struct PlaybackBar: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackStore.self) private var playback

    var body: some View {
        let ids = playback.nowPlaying.ids
        let current = ids.first.flatMap(library.block)
        TimelineView(.periodic(from: .now, by: 15)) { context in
            VStack(spacing: 0) {
                // While paused the line is hidden, not reset to 0: no sliding back, and nothing to
                // slide forward again on "Reprendre". The right-hand text already says "En pause".
                ProgressView(value: playback.nowPlaying.nextChange.map {
                    progress(nextChange: $0, intervalMinutes: library.config.intervalMinutes, now: context.date)
                } ?? 0)
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .opacity(playback.nowPlaying.paused ? 0 : 1)
                .transaction { $0.animation = nil }
                .accessibilityHidden(true)
                // Left and right take the same share around the controls, so the controls stay
                // centered and the texts truncate instead of running under them.
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        HStack(spacing: 3) {
                            ForEach(Array(Set(ids).sorted().prefix(4)), id: \.self) { id in
                                BlockPreview(block: library.block(id), maxPixels: 120)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: current.map { shortenedTitle($0.title ?? String(localized: "Sans titre"), max: 32) } ?? String(localized: "Aucune image affichée"))
                                .font(.callout.weight(.medium)).lineLimit(1).truncationMode(.tail)
                            Text("À l'écran").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    controls.fixedSize()
                    Text(nextChangeText(playback.nowPlaying, now: context.date))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(.bar)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button { Task { await playback.previous() } } label: { Image(systemName: "backward.fill") }
                .help(Text("Précédent (⌘←)"))
                .accessibilityLabel(Text("Précédent"))
            Button { Task { await playback.togglePause() } } label: {
                Image(systemName: playback.nowPlaying.paused ? "play.fill" : "pause.fill").font(.title2)
            }
            .help(playback.nowPlaying.paused ? Text("Reprendre (espace)") : Text("Pause (espace)"))
            .accessibilityLabel(playback.nowPlaying.paused ? Text("Reprendre") : Text("Pause"))
            Button { Task { await playback.next() } } label: { Image(systemName: "forward.fill") }
                .help(Text("Suivant (⌘→)"))
                .accessibilityLabel(Text("Suivant"))
        }
        .font(.title3)
        .buttonStyle(.plain)
    }
}
