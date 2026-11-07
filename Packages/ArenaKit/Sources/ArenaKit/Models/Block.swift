import Foundation

/// An image block of an Are.na channel.
public struct Block: Codable, Hashable, Sendable {
    public var id: Int
    public var title: String?
    /// The original image.
    public var fullURL: URL
    /// Small version for the grid.
    public var thumbURL: URL
    /// Larger version for the menu bar panel.
    public var previewURL: URL
    public var width: Int?
    public var height: Int?
    public var fileSize: Int?
    public var contentType: String?

    public init(
        id: Int, title: String?, fullURL: URL, thumbURL: URL, previewURL: URL,
        width: Int? = nil, height: Int? = nil, fileSize: Int? = nil, contentType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.fullURL = fullURL
        self.thumbURL = thumbURL
        self.previewURL = previewURL
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.contentType = contentType
    }

    public var isGIF: Bool { contentType == "image/gif" }
}
