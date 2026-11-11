import AppKit
import SwiftUI
import ArenaKit

/// Content of the menu bar popover: the current image, the countdown and the actions.
struct PanelView: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(ErrorCenter.self) private var errors
    let openLibrary: () -> Void
    let openPreferences: () -> Void

    private var block: Block? { playback.nowPlaying.ids.first.flatMap(library.block) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelArt(block: block)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subtitle(now: context.date)).font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: progressValue(now: context.date))
                            .opacity(playback.nowPlaying.paused ? 0.35 : 1)
                    }
                }
            }
            HStack(spacing: 8) {
                Button { Task { await playback.next() } } label: {
                    Label("Suivant", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                }
                Button { Task { await playback.togglePause() } } label: {
                    Label(playback.nowPlaying.paused ? String(localized: "Reprendre") : String(localized: "Pause"), systemImage: playback.nowPlaying.paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            Divider()
            HStack {
                Button(allExcluded ? String(localized: "Remettre") : String(localized: "Retirer")) { Task { await app.toggleExcluded(playback.nowPlaying.ids) } }
                    .disabled(playback.nowPlaying.ids.isEmpty)
                Button("Are.na") { playback.nowPlaying.ids.first.map(library.openOnArena) }
                    .disabled(playback.nowPlaying.ids.isEmpty)
                    .accessibilityLabel(Text("Ouvrir sur Are.na"))
                Spacer()
                Button("Bibliothèque", action: openLibrary)
                Button("Préférences", action: openPreferences)
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            if let error = errors.message {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var allExcluded: Bool {
        !playback.nowPlaying.ids.isEmpty && playback.nowPlaying.ids.allSatisfy(library.isExcluded)
    }

    private var title: String {
        guard let block else { return String(localized: "Aucune image affichée") }
        let others = Set(playback.nowPlaying.ids).count - 1
        return shortenedTitle(block.title ?? String(localized: "Sans titre"), max: 34) + (others > 0 ? " (+\(others))" : "")
    }

    private func subtitle(now: Date) -> String {
        if playback.nowPlaying.paused { return String(localized: "En pause") }
        guard let next = playback.nowPlaying.nextChange else { return "" }
        let minutes = remainingMinutes(until: next, now: now)
        return minutes == 0 ? String(localized: "Prochain changement dans moins d'une minute") : String(localized: "Prochain changement dans \(minutes) min")
    }

    private func progressValue(now: Date) -> Double {
        guard let next = playback.nowPlaying.nextChange else { return 0 }
        return progress(nextChange: next, intervalMinutes: library.config.intervalMinutes, now: now)
    }
}

/// The current image (first frame for a GIF), 16:10, loaded at most 600 px wide.
private struct PanelArt: View {
    let block: Block?
    @State private var image: NSImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay {
                if let image { Image(nsImage: image).resizable().scaledToFill() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                if block?.isGIF == true {
                    Text("GIF animé").font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(block?.title.map { Text(verbatim: $0) } ?? Text("Aucune image affichée"))
            .task(id: block?.id) {
                image = nil
                guard let block, let (data, _) = try? await URLSession.shared.data(from: block.previewURL) else { return }
                image = Thumbnails.downscale(data, maxPixels: 600)
            }
    }
}
