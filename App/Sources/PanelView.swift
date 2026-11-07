import AppKit
import SwiftUI
import ArenaKit

/// Content of the menu bar popover: the current image, the countdown and the actions.
struct PanelView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void

    private var block: Block? { model.nowPlaying.ids.first.flatMap(model.block) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelArt(block: block)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(subtitle(now: context.date)).font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: progressValue(now: context.date))
                            .opacity(model.nowPlaying.paused ? 0.35 : 1)
                    }
                }
            }
            HStack(spacing: 8) {
                Button { Task { await model.next() } } label: {
                    Label("Suivant", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                }
                Button { Task { await model.togglePause() } } label: {
                    Label(model.nowPlaying.paused ? "Reprendre" : "Pause", systemImage: model.nowPlaying.paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            Divider()
            HStack {
                Button(allExcluded ? "Réinclure" : "Exclure") { Task { await model.toggleExcluded(model.nowPlaying.ids) } }
                    .disabled(model.nowPlaying.ids.isEmpty)
                Button("Are.na") { model.nowPlaying.ids.first.map(model.openOnArena) }
                    .disabled(model.nowPlaying.ids.isEmpty)
                    .accessibilityLabel("Ouvrir sur Are.na")
                Spacer()
                Button("Réglages", action: openSettings)
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var allExcluded: Bool {
        !model.nowPlaying.ids.isEmpty && model.nowPlaying.ids.allSatisfy(model.isExcluded)
    }

    private var title: String {
        guard let block else { return "Aucune image affichée" }
        let others = Set(model.nowPlaying.ids).count - 1
        return shortenedTitle(block.title ?? "Sans titre", max: 34) + (others > 0 ? " (+\(others))" : "")
    }

    private func subtitle(now: Date) -> String {
        if model.nowPlaying.paused { return "En pause" }
        guard let next = model.nowPlaying.nextChange else { return "" }
        let minutes = remainingMinutes(until: next, now: now)
        return minutes == 0 ? "Prochain changement dans moins d'une minute" : "Prochain changement dans \(minutes) min"
    }

    private func progressValue(now: Date) -> Double {
        guard let next = model.nowPlaying.nextChange else { return 0 }
        return progress(nextChange: next, intervalMinutes: model.config.intervalMinutes, now: now)
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
            .accessibilityLabel(block?.title ?? "Aucune image affichée")
            .task(id: block?.id) {
                image = nil
                guard let block, let (data, _) = try? await URLSession.shared.data(from: block.previewURL) else { return }
                image = Thumbnails.downscale(data, maxPixels: 600)
            }
    }
}
