/// A channel added by the user, with its image blocks.
public struct Channel: Codable, Hashable, Sendable {
    public var slug: String
    public var enabled: Bool
    public var blocks: [Block]

    public init(slug: String, enabled: Bool = true, blocks: [Block] = []) {
        self.slug = slug
        self.enabled = enabled
        self.blocks = blocks
    }
}
