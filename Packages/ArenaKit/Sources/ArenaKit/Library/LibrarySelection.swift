/// What the library grid shows: every image of the active channels, or one channel.
public enum LibrarySelection: Hashable, Sendable {
    case all
    case channel(String)
}

/// The images of a selection, without repeats, in the order of the channels: those in the
/// playback, or with `removed`, only those taken out of it (for `.all`, from every channel,
/// paused ones included). The two lists never share an image.
public func blocks(for selection: LibrarySelection, in config: Config, removed: Bool = false) -> [Block] {
    let excluded = Set(config.excluded)
    var seen = Set<Int>()
    func unique(_ blocks: [Block]) -> [Block] {
        blocks.filter { seen.insert($0.id).inserted && excluded.contains($0.id) == removed }
    }
    switch selection {
    case .all:
        return unique((removed ? config.channels : config.channels.filter(\.enabled)).flatMap(\.blocks))
    case .channel(let slug):
        return unique(config.channels.first { $0.slug == slug }?.blocks ?? [])
    }
}
