/// What the library grid shows: every image of the active channels, or one channel.
public enum LibrarySelection: Hashable, Sendable {
    case all
    case channel(String)
}

/// The images of a selection, without repeats, in the order of the channels. With `removedOnly`,
/// only the images taken out of the playback (for `.all`, from every channel, paused ones included).
public func blocks(for selection: LibrarySelection, in config: Config, removedOnly: Bool = false) -> [Block] {
    let removed = Set(config.excluded)
    var seen = Set<Int>()
    func unique(_ blocks: [Block]) -> [Block] {
        blocks.filter { seen.insert($0.id).inserted && (!removedOnly || removed.contains($0.id)) }
    }
    switch selection {
    case .all:
        return unique((removedOnly ? config.channels : config.channels.filter(\.enabled)).flatMap(\.blocks))
    case .channel(let slug):
        return unique(config.channels.first { $0.slug == slug }?.blocks ?? [])
    }
}
