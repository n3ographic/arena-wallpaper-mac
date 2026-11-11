import Foundation

/// A channel added by the user, with the image blocks loaded so far.
public struct Channel: Codable, Hashable, Sendable {
    public var slug: String
    public var enabled: Bool
    public var blocks: [Block]
    /// The next page to load; nil when Are.na has no more.
    public var nextPage: Int?
    /// The ETag of page 1, to revalidate it.
    public var etag: String?
    /// The last successful revalidation (a 304 counts).
    public var lastRefresh: Date?

    public init(slug: String, enabled: Bool = true, blocks: [Block] = [], nextPage: Int? = nil, etag: String? = nil, lastRefresh: Date? = nil) {
        self.slug = slug
        self.enabled = enabled
        self.blocks = blocks
        self.nextPage = nextPage
        self.etag = etag
        self.lastRefresh = lastRefresh
    }
}
