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
                ProgressView(value: playback.nowPlaying.paused ? 0 : playback.nowPlaying.nextChange.map {
                    progress(nextChange: $0, intervalMinutes: library.config.intervalMinutes, now: context.date)
                } ?? 0)
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .accessibilityHidden(true)
                ZStack {
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
                                .font(.callout.weight(.medium)).lineLimit(1)
                            Text("À l'écran").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(nextChangeText(playback.nowPlaying, now: context.date))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    controls
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
