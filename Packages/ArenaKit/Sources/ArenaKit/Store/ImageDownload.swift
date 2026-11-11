import Foundation

/// Downloads an image from an address given by the Are.na API: HTTPS only, to a temporary file
/// (not memory), and refused above `maxBytes` before it is read.
// ponytail: the file is fully downloaded to disk before the size check; a hard cap during the
// transfer needs a URLSession delegate, add it if oversized images show up in practice.
public func downloadImage(_ url: URL, session: URLSession = .shared, maxBytes: Int = maxImageFileSize) async throws -> Data {
    guard url.scheme?.lowercased() == "https" else { throw ImageCacheError.download("not https") }
    let file: URL
    let response: URLResponse
    do {
        (file, response) = try await session.download(from: url)
    } catch {
        throw ImageCacheError.download(error.localizedDescription)
    }
    defer { try? FileManager.default.removeItem(at: file) }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else { throw ImageCacheError.download("HTTP \(status)") }
    let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int ?? 0
    guard size <= maxBytes else { throw ImageCacheError.tooLarge }
    do {
        return try Data(contentsOf: file)
    } catch {
        throw ImageCacheError.download(error.localizedDescription)
    }
}
