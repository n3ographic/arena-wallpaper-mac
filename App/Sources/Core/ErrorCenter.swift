import ArenaKit
import Foundation
import Observation

/// The one place an error message is kept for display; cleared by the next successful action.
@MainActor @Observable
final class ErrorCenter {
    private(set) var message: String?

    func report(_ error: Error) {
        message = Self.message(for: error)
    }

    func report(_ text: String) {
        message = text
    }

    func clear() {
        message = nil
    }

    nonisolated static func message(for error: Error) -> String {
        switch error {
        case LibraryError.invalidChannel: return String(localized: "Lien ou slug de channel invalide.")
        case LibraryError.alreadyAdded: return String(localized: "Ce channel est déjà ajouté.")
        case ArenaError.unauthorized: return String(localized: "Reconnecte-toi à Are.na.")
        case ArenaError.forbidden: return String(localized: "Ce channel est privé : Are.na ne le partage pas.")
        case ArenaError.notFound: return String(localized: "Channel introuvable ou privé.")
        case ArenaError.rateLimited(let seconds): return String(localized: "Are.na limite les requêtes : réessaie dans \(seconds) s.")
        case ArenaError.network(let detail): return String(localized: "Réseau indisponible (\(detail)).")
        case OAuthError.tokenRejected(let status): return String(localized: "Are.na a refusé la connexion (code \(status)). Utilise un token personnel.")
        case OAuthError.denied: return String(localized: "Connexion refusée.")
        case OAuthError.stateMismatch, OAuthError.missingCode: return String(localized: "Réponse de connexion invalide, réessaie.")
        case ImageCacheError.tooLarge: return String(localized: "Image trop lourde.")
        case ImageCacheError.unreadable, RenderError.unreadable: return String(localized: "Image illisible.")
        case ImageCacheError.download(let detail): return String(localized: "Téléchargement impossible (\(detail)).")
        case ApplyError.allScreensFailed(let detail): return String(localized: "Le système a refusé le fond d'écran (\(detail)).")
        case ApplyError.unknownImage: return String(localized: "Image introuvable, actualise les channels.")
        default: return error.localizedDescription
        }
    }
}
