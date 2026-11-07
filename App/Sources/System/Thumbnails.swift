import AppKit
import ImageIO
import ArenaKit

/// Small grid images: downscaled to 400 px (first frame for a GIF) and kept in memory
/// only while the settings window is open.
@MainActor
final class Thumbnails {
    static let shared = Thumbnails()
    private let cache = NSCache<NSNumber, NSImage>()

    func image(for block: Block) async -> NSImage? {
        if let cached = cache.object(forKey: block.id as NSNumber) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: block.thumbURL),
              let image = Self.downscale(data, maxPixels: 400) else { return nil }
        cache.setObject(image, forKey: block.id as NSNumber)
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }

    nonisolated static func downscale(_ data: Data, maxPixels: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
