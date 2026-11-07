import Foundation

/// If all these images are excluded, brings them back; otherwise excludes them all.
public func toggleExclusion(_ ids: [Int], in config: inout Config) {
    let unique = Array(NSOrderedSet(array: ids)) as! [Int]
    let allExcluded = !unique.isEmpty && unique.allSatisfy(config.excluded.contains)
    config.excluded.removeAll { unique.contains($0) }
    if !allExcluded {
        config.excluded.append(contentsOf: unique)
    }
}

/// The page of an image on Are.na, where the user can also report or block.
public func blockURL(_ id: Int) -> URL {
    URL(string: "https://www.are.na/block/\(id)")!
}
