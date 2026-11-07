import Foundation

/// The slug of a channel from a pasted link (`https://www.are.na/user/slug`) or a bare slug.
public func parseChannelSlug(_ input: String) -> String? {
    var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if let cut = text.firstIndex(where: { $0 == "?" || $0 == "#" }) {
        text = String(text[..<cut])
    }
    let candidate = text.split(separator: "/").last.map(String.init) ?? ""
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
    guard !candidate.isEmpty, candidate.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
    return candidate
}
