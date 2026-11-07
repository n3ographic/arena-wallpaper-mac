/// Above these limits the image is skipped: no minimum size (small GIFs are welcome).
public let maxImageFileSize = 52_428_800
public let maxImagePixels = 100_000_000

/// False for images known to be too heavy; unknown sizes are accepted.
public func isUsable(_ block: Block) -> Bool {
    if let size = block.fileSize, size > maxImageFileSize { return false }
    if let w = block.width, let h = block.height, w * h > maxImagePixels { return false }
    return true
}
