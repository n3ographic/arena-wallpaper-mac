import AppKit
import SwiftUI
import ArenaKit

/// Content of the menu bar popover, like a music player: the image on screen with its own
/// "…" menu, what it is and when it changes, the controls; then a thin bar for the app.
struct PanelView: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    @Environment(ErrorCenter.self) private var errors
    let openLibrary: () -> Void
    let openPreferences: () -> Void
    let openAbout: () -> Void

    private var block: Block? { playback.nowPlaying.ids.first.flatMap(library.block) }
    private var showsScreenRow: Bool { library.config.screenMode == .perScreen && display.screens.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsScreenRow {
                PanelScreensRow(openLibrary: openLibrary)
            } else {
                PanelArt(block: block)
                    .overlay(alignment: .topTrailing) {
                        if let block { ImageMenu(block: block, openLibrary: openLibrary).padding(6) }
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subtitle(now: context.date)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        ProgressView(value: progressValue(now: context.date))
                            .opacity(playback.nowPlaying.paused ? 0.35 : 1)
                    }
                }
            }
            PanelControls()
            Divider()
            PanelFooter(openLibrary: openLibrary, openPreferences: openPreferences, openAbout: openAbout)
            if let error = errors.message {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var title: String {
        guard let block else { return String(localized: "Aucune image affichée") }
        let others = Set(playback.nowPlaying.ids).count - 1
        return shortenedTitle(block.title ?? String(localized: "Sans titre"), max: 34) + (others > 0 ? " (+\(others))" : "")
    }

    /// The channel of the image, then the time to the next change.
    private func subtitle(now: Date) -> String {
        let channel = block.flatMap { block in library.config.channels.first { $0.blocks.contains { $0.id == block.id } }?.slug }
        return [channel, nextChangeText(playback.nowPlaying, now: now)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func progressValue(now: Date) -> Double {
        guard let next = playback.nowPlaying.nextChange else { return 0 }
        return progress(nextChange: next, intervalMinutes: library.config.intervalMinutes, now: now)
    }
}

/// The "…" button on an image: everything about that image.
private struct ImageMenu: View {
    @Environment(AppCoordinator.self) private var app
    @Environment(LibraryStore.self) private var library
    let block: Block
    let openLibrary: () -> Void

    var body: some View {
        Menu {
            Button("Ouvrir sur Are.na") { library.openOnArena(block.id) }
            Button(library.isExcluded(block.id) ? String(localized: "Remettre dans la lecture") : String(localized: "Retirer de la lecture")) {
                Task { await app.toggleExcluded([block.id]) }
            }
            Button("Afficher dans la bibliothèque") {
                app.sidebarItem = .images(.all)
                app.reveal = block.id
                openLibrary()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout.weight(.semibold))
                .frame(width: 26, height: 26)
                .background(.regularMaterial, in: Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("Actions sur cette image"))
        .accessibilityLabel(Text("Actions sur cette image"))
    }
}

/// Previous, pause, next, centered.
private struct PanelControls: View {
    @Environment(PlaybackStore.self) private var playback

    var body: some View {
        HStack(spacing: 28) {
            Button { Task { await playback.previous() } } label: { Image(systemName: "backward.fill") }
                .help(Text("Précédent"))
                .accessibilityLabel(Text("Précédent"))
            Button { Task { await playback.togglePause() } } label: {
                Image(systemName: playback.nowPlaying.paused ? "play.fill" : "pause.fill").font(.title)
            }
            .help(playback.nowPlaying.paused ? Text("Reprendre") : Text("Pause"))
            .accessibilityLabel(playback.nowPlaying.paused ? Text("Reprendre") : Text("Pause"))
            Button { Task { await playback.next() } } label: { Image(systemName: "forward.fill") }
                .help(Text("Suivant"))
                .accessibilityLabel(Text("Suivant"))
        }
        .font(.title3)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

/// The app: the library, the rhythm, and a menu with the settings, about and quit.
private struct PanelFooter: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    let openLibrary: () -> Void
    let openPreferences: () -> Void
    let openAbout: () -> Void

    var body: some View {
        HStack {
            Button { openLibrary() } label: { Label("Bibliothèque", systemImage: "photo.on.rectangle") }
            Spacer()
            Menu {
                Picker("Rythme", selection: Binding(
                    get: { library.config.intervalMinutes },
                    set: { minutes in Task { await playback.setInterval(minutes) } }
                )) {
                    ForEach(intervalOptions(current: library.config.intervalMinutes), id: \.self) { minutes in
                        Text(intervalText(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(intervalText(library.config.intervalMinutes), systemImage: "clock")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("Rythme de la lecture"))
            Spacer()
            Menu {
                Button("Réglages…") { openPreferences() }
                Button("À propos de Wallpaper for Are.na") { openAbout() }
                Divider()
                Button("Quitter") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Text("Réglages"))
            .accessibilityLabel(Text("Réglages"))
        }
        .buttonStyle(.borderless)
        .lineLimit(1)
    }
}

func intervalText(_ minutes: Int) -> String {
    let label = intervalLabel(minutes)
    switch label.unit {
    case .minutes: return String(localized: "\(label.value) min")
    case .hours: return String(localized: "\(label.value) h")
    case .days: return String(localized: "\(label.value) j")
    }
}

/// The current image (first frame for a GIF), 16:10, loaded at most 600 px wide.
struct PanelArt: View {
    let block: Block?

    var body: some View {
        BlockPreview(block: block, maxPixels: 600)
            .aspectRatio(16 / 10, contentMode: .fit)
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
    }
}

/// One small thumbnail per screen, each with its own "next" button.
struct PanelScreensRow: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(LibraryStore.self) private var library
    @Environment(DisplayStore.self) private var display
    let openLibrary: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(display.screens.enumerated()), id: \.element.id) { index, screen in
                let ids = playback.nowPlaying.ids
                let block = (ids.indices.contains(index) ? ids[index] : ids.first).flatMap(library.block)
                VStack(spacing: 4) {
                    BlockPreview(block: block, maxPixels: 300)
                        .aspectRatio(CGFloat(screen.frame.width) / CGFloat(max(1, screen.frame.height)), contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(Text(verbatim: block?.title ?? String(localized: "Aucune image affichée")))
                        .overlay(alignment: .topTrailing) {
                            if let block { ImageMenu(block: block, openLibrary: openLibrary).padding(4) }
                        }
                    Button { Task { await playback.next(screenID: screen.id) } } label: {
                        Label("Suivant", systemImage: "forward.end.fill").labelStyle(.iconOnly).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Image suivante pour l'écran \(index + 1)"))
                }
            }
        }
    }
}

/// "En pause", or the time left before the next automatic change.
func nextChangeText(_ state: NowPlaying, now: Date) -> String {
    if state.paused { return String(localized: "En pause") }
    guard let next = state.nextChange else { return "" }
    let minutes = remainingMinutes(until: next, now: now)
    return minutes == 0 ? String(localized: "Prochain changement dans moins d'une minute") : String(localized: "Prochain changement dans \(minutes) min")
}
