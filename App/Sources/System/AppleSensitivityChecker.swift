#if SENSITIVE_CONTENT
import Foundation
import SensitiveContentAnalysis
import ArenaKit

/// Apple's on-device detection. Only in builds signed with the paid developer account
/// (restricted entitlement), and only active when the user turned on Sensitive Content
/// Warning in System Settings. Results never leave the device.
struct AppleSensitivityChecker: SensitivityChecker {
    func isActive() async -> Bool {
        SCSensitivityAnalyzer().analysisPolicy != .disabled
    }

    func isSensitive(_ file: URL) async throws -> Bool {
        try await SCSensitivityAnalyzer().analyzeImage(at: file).isSensitive
    }
}
#endif
