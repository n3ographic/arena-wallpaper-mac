import Foundation
import ArenaKit

/// Waits until the next change, rotates, and starts again. Any manual action or change of
/// rhythm restarts the wait; the library is told after each rotation.
@MainActor
final class RotationClock {
    private let engine: RotationEngine
    private let onError: (Error) -> Void
    private let onRotated: () async -> Void
    private var task: Task<Void, Never>?

    init(engine: RotationEngine, onError: @escaping (Error) -> Void, onRotated: @escaping () async -> Void) {
        self.engine = engine
        self.onError = onError
        self.onRotated = onRotated
    }

    func start(rotateNow: Bool) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            if rotateNow { await self.rotate() }
            while !Task.isCancelled {
                let next = await self.engine.scheduleNext()
                try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow)))
                if Task.isCancelled { return }
                await self.rotate()
                // Its own task: a refresh never delays the next draw, and restarting the clock
                // (which cancels this one) never cancels a refresh in progress.
                let onRotated = self.onRotated
                Task { await onRotated() }
            }
        }
    }

    /// A new full wait, without changing the image now.
    func restart() {
        start(rotateNow: false)
    }

    /// Runs in its own task: restarting the clock cancels the wait, never a rotation in
    /// progress (a cancelled download would make it fall back on a random cached image).
    private func rotate() async {
        let engine = self.engine
        do {
            try await Task { try await engine.rotate(manual: false) }.value
        } catch {
            onError(error)
        }
    }
}
