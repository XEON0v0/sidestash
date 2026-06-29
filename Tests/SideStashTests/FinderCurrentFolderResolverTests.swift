import AppKit
import Foundation
import Testing
@testable import SideStash

struct FinderCurrentFolderResolverTests {
    @Test func resolver_attemptsResolutionWhenSideStashIsFrontmost() {
        #expect(FinderCurrentFolderResolver.shouldAttemptFinderResolution(frontmostBundleIdentifier: "app.sidestash.SideStash"))
    }

    @Test func resolver_attemptsResolutionWhenFinderIsFrontmost() {
        #expect(FinderCurrentFolderResolver.shouldAttemptFinderResolution(frontmostBundleIdentifier: "com.apple.finder"))
    }

    @Test func resolver_identifiesAutomationPermissionDeniedError() {
        let errorInfo: NSDictionary = [
            NSAppleScript.errorNumber: -1743,
            NSAppleScript.errorMessage: "Not authorized to send Apple events to Finder."
        ]

        #expect(FinderCurrentFolderResolver.resolutionFailureReason(from: errorInfo) == .automationPermissionDenied)
    }
}
