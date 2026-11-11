import AppKit
import SwiftUI

/// "About Arena Wallpaper": version, updates and links, opened from the app menu or the popover.
struct AboutView: View {
    @StateObject private var updates = UpdateChecker()

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(verbatim: "Arena Wallpaper").font(.title2.weight(.semibold))
                Text("Version \(UpdateChecker.currentVersion) (\(UpdateChecker.build))")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                updateStatus.foregroundStyle(.secondary)
                switch updates.status {
                case .newer(_, let page):
                    Link("Télécharger", destination: page).buttonStyle(.borderedProminent)
                default:
                    Button("Rechercher une mise à jour") { Task { await updates.check() } }
                        .disabled(updates.status == .checking)
                }
            }
            HStack(spacing: 16) {
                Link("Code source sur GitHub", destination: UpdateChecker.repository)
                Link("Signaler un problème", destination: UpdateChecker.repository.appendingPathComponent("issues/new"))
            }
            .font(.callout)
            Text("Projet indépendant, non affilié à Are.na.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360)
        .task { await updates.check() }
    }

    private var updateStatus: Text {
        switch updates.status {
        case .idle, .checking: Text("Recherche en cours…")
        case .upToDate: Text("Tu as la dernière version.")
        case .failed: Text("Impossible de joindre GitHub.")
        case .newer(let version, _): Text("Version \(version) disponible")
        }
    }
}

/// One small window, shown again if already open; it counts for the Dock icon like the library.
@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            w.title = String(localized: "À propos d'Arena Wallpaper")
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
            DockPresence.opened()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        DockPresence.closed()
        DispatchQueue.main.async { [weak self] in self?.window = nil }
    }
}
