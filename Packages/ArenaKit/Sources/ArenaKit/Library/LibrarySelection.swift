/// What the library grid shows: everything in the rotation, the removed images, or one channel.
public enum LibrarySelection: Hashable, Sendable {
    case all
    case removed
    case channel(String)
    /// Not a list of images: the window shows the general settings.
    case general
}

/// The images of a selection, without repeats, in the order of the channels.
public func blocks(for selection: LibrarySelection, in config: Config) -> [Block] {
    let removed = Set(config.excluded)
    var seen = Set<Int>()
    func unique(_ blocks: [Block]) -> [Block] {
        blocks.filter { seen.insert($0.id).inserted }
    }
    switch selection {
    case .all:
        return unique(config.channels.filter(\.enabled).flatMap(\.blocks))
    case .removed:
        return unique(config.channels.flatMap(\.blocks).filter { removed.contains($0.id) })
    case .channel(let slug):
        return unique(config.channels.first { $0.slug == slug }?.blocks ?? [])
    case .general:
        return []
    }
}
