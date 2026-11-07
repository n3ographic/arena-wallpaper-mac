import Foundation

/// Rendered files to delete: everything but the `keep` newest and the ones just applied.
/// Older files are kept for a while because macOS only updates the active Space.
public func staleRenderedFiles(_ files: [(url: URL, modified: Date)], inUse: [URL], keep: Int) -> [URL] {
    files
        .sorted { $0.modified > $1.modified }
        .dropFirst(keep)
        .map(\.url)
        .filter { !inUse.contains($0) }
}
