import AppKit
import SwiftUI

/// Settings of the app itself, placed in the Playback and Account pages.

struct LaunchAtLoginToggle: View {
    @Environment(ErrorCenter.self) private var errors
    @State private var enabled = LaunchAtLogin.isEnabled

    var body: some View {
        Toggle("Lancer au démarrage", isOn: Binding(get: { enabled }, set: { set($0) }))
    }

    private func set(_ value: Bool) {
        do {
            try LaunchAtLogin.set(value)
        } catch {
            errors.report(error)
        }
        enabled = LaunchAtLogin.isEnabled
    }
}

struct LanguageSection: View {
    @State private var language = AppLanguage.current
    @State private var changed = false

    var body: some View {
        Section("Langue") {
            Picker("Langue de l'app", selection: Binding(get: { language }, set: { choose($0) })) {
                Text("Celle du système").tag(AppLanguage.system)
                Text(verbatim: "Français").tag(AppLanguage.french)
                Text(verbatim: "English").tag(AppLanguage.english)
            }
            if changed {
                LabeledContent("La langue change au prochain lancement.") {
                    Button("Relancer") { AppLanguage.relaunch() }
                }
            }
        }
    }

    private func choose(_ new: AppLanguage) {
        guard new != language else { return }
        language = new
        new.save()
        changed = true
    }
}

struct StorageSection: View {
    @Environment(LibraryStore.self) private var library
    @State private var cacheSize: Int?
    @State private var confirmsClear = false

    var body: some View {
        Section("Stockage") {
            LabeledContent("Images en cache") {
                if let cacheSize {
                    Text(cacheSize.formatted(.byteCount(style: .file)))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            Button("Vider le cache") { confirmsClear = true }
                .disabled((cacheSize ?? 0) == 0)
                .confirmationDialog("Vider le cache des images ?", isPresented: $confirmsClear) {
                    Button("Vider le cache", role: .destructive) {
                        Task {
                            await library.clearCache()
                            cacheSize = await library.cacheSize()
                        }
                    }
                } message: {
                    Text("Les images seront téléchargées à nouveau quand elles seront affichées.")
                }
        }
        .task { cacheSize = await library.cacheSize() }
    }
}

/// The app's own language, stored as the per-app `AppleLanguages` default that macOS reads at launch.
enum AppLanguage: Hashable {
    case system, french, english

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        switch (domain?[key] as? [String])?.first {
        case "fr"?: return .french
        case "en"?: return .english
        default: return .system
        }
    }

    func save() {
        switch self {
        case .system: UserDefaults.standard.removeObject(forKey: Self.key)
        case .french: UserDefaults.standard.set(["fr"], forKey: Self.key)
        case .english: UserDefaults.standard.set(["en"], forKey: Self.key)
        }
    }

    /// Opens a new instance of the app, then quits this one.
    @MainActor static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
