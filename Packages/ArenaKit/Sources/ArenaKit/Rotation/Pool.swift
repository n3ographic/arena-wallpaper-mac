/// Ids of the images the rotation may show: enabled channels, no duplicates, config order,
/// without the excluded images.
public func enabledPool(_ config: Config) -> [Int] {
    var seen = Set<Int>()
    let excluded = Set(config.excluded)
    return config.channels
        .filter(\.enabled)
        .flatMap { $0.blocks.map(\.id) }
        .filter { !excluded.contains($0) && seen.insert($0).inserted }
}
