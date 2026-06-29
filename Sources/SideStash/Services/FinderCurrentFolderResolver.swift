import AppKit
import Foundation
import OSLog

@MainActor
protocol FinderCurrentFolderResolving {
    func currentFinderFolder() -> URL?
}

@MainActor
final class FinderCurrentFolderResolver: FinderCurrentFolderResolving {
    enum FailureReason: Equatable {
        case automationPermissionDenied
        case scriptFailed
    }

    static let shared = FinderCurrentFolderResolver()

    private let logger = Logger(subsystem: "app.sidestash.SideStash", category: "FinderCurrentFolderResolver")

    private init() {}

    nonisolated static func shouldAttemptFinderResolution(frontmostBundleIdentifier: String?) -> Bool {
        true
    }

    nonisolated static func resolutionFailureReason(from errorInfo: NSDictionary) -> FailureReason {
        let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int
        if errorNumber == -1743 {
            return .automationPermissionDenied
        }
        return .scriptFailed
    }

    func currentFinderFolder() -> URL? {
        guard Self.shouldAttemptFinderResolution(frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else {
            return nil
        }

        let scriptSource = """
        tell application "Finder"
            if (count of Finder windows) is 0 then
                return POSIX path of (desktop as alias)
            end if
            return POSIX path of (target of front Finder window as alias)
        end tell
        """

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            logger.error("Failed to create Finder folder AppleScript")
            return nil
        }

        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let reason = Self.resolutionFailureReason(from: errorInfo)
            logger.error("Failed to resolve Finder folder: \(String(describing: errorInfo), privacy: .public), reason=\(String(describing: reason), privacy: .public)")
            return nil
        }

        guard let path = descriptor.stringValue, !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
