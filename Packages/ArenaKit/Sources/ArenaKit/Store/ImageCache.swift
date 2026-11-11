import Foundation
import ImageIO

public enum ImageCacheError: Error, Equatable {
    case tooLarge
    case unreadable
    case download(String)
}

/// Original images, downloaded once into `originals/<id>`. Nothing unreadable or too heavy is kept.
public actor ImageCache {
    private let directory: URL
    private let session: URLSession
    private let maxBytes: Int
    private let maxPixels: Int

    public init(directory: URL, session: URLSession = .shared, maxBytes: Int = maxImageFileSize, maxPixels: Int = maxImagePixels) {
        self.directory = directory
        self.session = session
        self.maxBytes = maxBytes
        self.maxPixels = maxPixels
    }

    public func cachedURL(for id: Int) -> URL? {
        let url = fileURL(id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func original(for block: Block) async throws -> URL {
        if let cached = cachedURL(for: block.id) { return cached }
        let data: Data
        let response: URLResponse
        do {
            // No custom User-Agent: the image CDN is not the API.
            (data, response) = try await session.data(from: block.fullURL)
        } catch {
            throw ImageCacheError.download(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ImageCacheError.download("HTTP \(status)") }
        guard data.count <= maxBytes else { throw ImageCacheError.tooLarge }
        guard let (width, height) = pixelSize(of: data) else { throw ImageCacheError.unreadable }
        guard width * height <= maxPixels else { throw ImageCacheError.tooLarge }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = fileURL(block.id)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Drops a cached original that turned out to be unusable, so it is fetched again next time.
    public func discard(_ id: Int) {
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    /// Bytes taken on disk by the cached originals.
    public func diskUsage() -> Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.reduce(0) { total, name in
            let size = (try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path))?[.size] as? Int
            return total + (size ?? 0)
        }
    }

    /// Removes every cached original; they are downloaded again when needed.
    public func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func fileURL(_ id: Int) -> URL {
        directory.appendingPathComponent(String(id))
    }

    private func pixelSize(of data: Data) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }
}
