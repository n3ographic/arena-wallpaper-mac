import Foundation
import ArenaKit

/// Waits until the next change, rotates, and starts again. Any manual action or change of
/// rhythm restarts the wait; the library is refreshed once a day.
@MainActor
final class RotationClock {
    private static let refreshEvery: TimeInterval = 24 * 3600

    private let engine: RotationEngine
    private let onError: (Error) -> Void
    private let onDailyRefresh: () async -> Void
    private var task: Task<Void, Never>?
    private var lastRefresh = Date()

    init(engine: RotationEngine, onError: @escaping (Error) -> Void, onDailyRefresh: @escaping () async -> Void) {
        self.engine = engine
        self.onError = onError
        self.onDailyRefresh = onDailyRefresh
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
                if Date().timeIntervalSince(self.lastRefresh) > Self.refreshEvery {
                    self.lastRefresh = Date()
                    await self.onDailyRefresh()
                }
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
