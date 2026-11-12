import Foundation

extension Block {
    /// True when filling the largest of `screens` would enlarge the image by more than 2 times,
    /// so it will look soft. Unknown sizes are never flagged.
    public func isLowResolution(for screens: [Screen]) -> Bool {
        guard let width, let height, width > 0, height > 0,
              let screen = screens.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else { return false }
        let scale = max(Double(screen.frame.width) / Double(width), Double(screen.frame.height) / Double(height))
        return scale > 2
    }
}
