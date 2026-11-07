/// Ids of the images the rotation may show: enabled channels, no duplicates, config order,
/// without the excluded images nor the flagged ones the user did not allow.
public func enabledPool(_ config: Config) -> [Int] {
    var seen = Set<Int>()
    let excluded = Set(config.excluded)
    let allowed = Set(config.sensitiveAllowed)
    return config.channels
        .filter(\.enabled)
        .flatMap { $0.blocks.map(\.id) }
        .filter { id in
            let flagged = config.sensitiveVerdicts[id] == true && !allowed.contains(id)
            return !excluded.contains(id) && !flagged && seen.insert(id).inserted
        }
}
