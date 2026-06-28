import AppKit
import Combine
import CoreGraphics
import OSLog

struct FinderWindowSnapshot: Equatable {
    let windowID: Int?
    let rect: NSRect
}

@MainActor
final class FinderWindowTracker {
    static let shared = FinderWindowTracker()

    private let logger = Logger(subsystem: "app.sidestash.SideStash", category: "FinderWindowTracker")
    private let finderBundleID = "com.apple.finder"

    private var axObserver: AXObserver?
    private var activateObserver: NSObjectProtocol?
    private var deactivateObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var isMonitoring = false

    @Published private(set) var activeFinderWindowRect: NSRect?
    private(set) var activeFinderWindowSnapshot: FinderWindowSnapshot?

    var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        registerWorkspaceObservers()

        guard isAccessibilityGranted else {
            logger.warning("Accessibility permission not granted. Falling back to CGWindow-based Finder tracking.")
            refreshFinderWindowRectFromWindowServer()
            return
        }

        guard let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first else {
            logger.warning("Finder is not running.")
            return
        }

        let pid = finderApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let tracker = Unmanaged<FinderWindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            Task { @MainActor in
                tracker.updateActiveFinderWindowRect()
            }
        }

        var observer: AXObserver?
        let createResult = AXObserverCreate(pid, callback, &observer)
        guard createResult == .success, let observer = observer else {
            logger.error("Failed to create AXObserver: \(createResult.rawValue)")
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [(AXUIElement, String)] = [
            (appElement, kAXFocusedWindowChangedNotification),
            (appElement, kAXApplicationActivatedNotification),
            (appElement, kAXWindowMovedNotification),
            (appElement, kAXWindowResizedNotification),
        ]

        for (element, notification) in notifications {
            let result = AXObserverAddNotification(observer, element, notification as CFString, refcon)
            if result != .success {
                logger.warning("Failed to register AX notification \(notification): \(result.rawValue)")
            }
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        axObserver = observer

        updateActiveFinderWindowRect()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            axObserver = nil
        }

        if let token = activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            activateObserver = nil
        }
        if let token = deactivateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            deactivateObserver = nil
        }
        if let token = terminateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            terminateObserver = nil
        }

        activeFinderWindowRect = nil
        activeFinderWindowSnapshot = nil
    }

    func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func updateActiveFinderWindowRect() {
        guard isAccessibilityGranted else {
            refreshFinderWindowRectFromWindowServer()
            return
        }

        guard let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first else {
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return
        }

        let appElement = AXUIElementCreateApplication(finderApp.processIdentifier)

        guard let windowElement = copyTrackedWindowElement(from: appElement) else {
            activeFinderWindowRect = nil
            return
        }

        var positionCF: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionCF)
        guard posResult == .success, let positionCF = positionCF else {
            logger.debug("Failed to get window position: \(posResult.rawValue)")
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return
        }
        let axPosition = positionCF as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(axPosition, .cgPoint, &point) else {
            logger.debug("Failed to extract CGPoint from AXValue")
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return
        }

        var sizeCF: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeCF)
        guard sizeResult == .success, let sizeCF = sizeCF else {
            logger.debug("Failed to get window size: \(sizeResult.rawValue)")
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return
        }
        let axSize = sizeCF as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(axSize, .cgSize, &size) else {
            logger.debug("Failed to extract CGSize from AXValue")
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return
        }

        let accessibilityRect = CGRect(origin: point, size: size)
        let screenFrame = screenContaining(accessibilityRect)?.frame ?? NSScreen.main?.frame ?? .zero
        let rect = Self.appKitRect(
            fromAccessibilityRect: accessibilityRect,
            onScreenFrame: screenFrame
        )

        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let snapshot = Self.accessibilitySnapshot(
            fromAccessibilityRect: accessibilityRect,
            fromWindowInfo: info,
            finderPID: finderApp.processIdentifier,
            screenFrame: screenFrame
        ) ?? FinderWindowSnapshot(windowID: nil, rect: rect)

        logger.debug("Updated Finder window rect ax=\(String(describing: accessibilityRect), privacy: .public) appKit=\(String(describing: rect), privacy: .public)")
        activeFinderWindowRect = snapshot.rect
        activeFinderWindowSnapshot = snapshot
    }

    private func handleWorkspaceActivate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        if app.bundleIdentifier == finderBundleID {
            updateActiveFinderWindowRect()
        } else if !isAccessibilityGranted {
            refreshFinderWindowRectFromWindowServer()
        }
    }

    private func handleWorkspaceDeactivate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        if app.bundleIdentifier == finderBundleID {
            updateActiveFinderWindowRect()
        } else if !isAccessibilityGranted {
            refreshFinderWindowRectFromWindowServer()
        }
    }

    private func handleWorkspaceTerminate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        if app.bundleIdentifier == finderBundleID {
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
        }
    }

    func refreshAttachedFinderWindowSnapshot(windowID: Int?, preferredRect: NSRect?) -> FinderWindowSnapshot? {
        guard let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first else {
            activeFinderWindowRect = nil
            activeFinderWindowSnapshot = nil
            return nil
        }

        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let referencePoint = preferredRect.map { NSPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first(where: { NSPointInRect(referencePoint, $0.frame) })?.frame
            ?? NSScreen.main?.frame
            ?? .zero

        let snapshot: FinderWindowSnapshot?
        if let windowID {
            snapshot = Self.finderWindowSnapshot(
                windowID: windowID,
                fromWindowInfo: info,
                screenFrame: screenFrame
            )
        } else {
            snapshot = Self.bestFinderWindowSnapshot(
                fromWindowInfo: info,
                finderPID: finderApp.processIdentifier,
                preferredRect: preferredRect,
                preferredPoint: preferredRect.map { NSPoint(x: $0.midX, y: $0.midY) },
                preferredWindowID: nil,
                screenFrame: screenFrame
            )
        }

        activeFinderWindowSnapshot = snapshot
        activeFinderWindowRect = snapshot?.rect
        logger.debug("Refreshed attached Finder window snapshot id=\(String(describing: snapshot?.windowID), privacy: .public) rect=\(String(describing: snapshot?.rect), privacy: .public)")
        return snapshot
    }

    private func copyTrackedWindowElement(from appElement: AXUIElement) -> AXUIElement? {
        if let focusedWindow = copyWindowElement(appElement: appElement, attribute: kAXFocusedWindowAttribute) {
            return focusedWindow
        }

        if let mainWindow = copyWindowElement(appElement: appElement, attribute: kAXMainWindowAttribute) {
            return mainWindow
        }

        logger.debug("Failed to get tracked Finder window from focused/main attributes")
        return nil
    }

    private func copyWindowElement(appElement: AXUIElement, attribute: String) -> AXUIElement? {
        var windowCF: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, attribute as CFString, &windowCF)
        guard result == .success, let windowCF = windowCF else {
            logger.debug("Failed to get Finder window for attribute \(attribute): \(result.rawValue)")
            return nil
        }

        guard CFGetTypeID(windowCF) == AXUIElementGetTypeID() else {
            logger.debug("Finder window attribute \(attribute) returned unexpected AX type")
            return nil
        }

        return unsafeBitCast(windowCF, to: AXUIElement.self)
    }

    nonisolated static func appKitRect(fromAccessibilityRect rect: CGRect, onScreenFrame screenFrame: NSRect) -> NSRect {
        let convertedY = screenFrame.maxY - rect.origin.y - rect.height
        return NSRect(x: rect.origin.x, y: convertedY, width: rect.width, height: rect.height)
    }

    nonisolated static func bestFinderWindowRect(
        fromWindowInfo windowInfo: [[String: Any]],
        finderPID: pid_t,
        preferredPoint: NSPoint,
        screenFrame: NSRect
    ) -> NSRect? {
        bestFinderWindowSnapshot(
            fromWindowInfo: windowInfo,
            finderPID: finderPID,
            preferredRect: nil,
            preferredPoint: preferredPoint,
            preferredWindowID: nil,
            screenFrame: screenFrame
        )?.rect
    }

    nonisolated static func accessibilitySnapshot(
        fromAccessibilityRect rect: CGRect,
        fromWindowInfo windowInfo: [[String: Any]],
        finderPID: pid_t,
        screenFrame: NSRect
    ) -> FinderWindowSnapshot? {
        let appKitRect = appKitRect(fromAccessibilityRect: rect, onScreenFrame: screenFrame)
        return bestFinderWindowSnapshot(
            fromWindowInfo: windowInfo,
            finderPID: finderPID,
            preferredRect: appKitRect,
            preferredPoint: NSPoint(x: appKitRect.midX, y: appKitRect.midY),
            preferredWindowID: nil,
            screenFrame: screenFrame
        ) ?? FinderWindowSnapshot(windowID: nil, rect: appKitRect)
    }

    nonisolated static func bestFinderWindowSnapshot(
        fromWindowInfo windowInfo: [[String: Any]],
        finderPID: pid_t,
        preferredRect: NSRect?,
        preferredPoint: NSPoint?,
        preferredWindowID: Int?,
        screenFrame: NSRect
    ) -> FinderWindowSnapshot? {
        let finderSnapshots = finderWindowSnapshots(
            fromWindowInfo: windowInfo,
            finderPID: finderPID,
            screenFrame: screenFrame
        )

        guard !finderSnapshots.isEmpty else { return nil }

        if let preferredWindowID,
           let exactSnapshot = finderSnapshots.first(where: { $0.windowID == preferredWindowID }) {
            return exactSnapshot
        }

        if let preferredRect,
           let matchingSnapshot = finderSnapshots.min(by: {
               rectDistance($0.rect, preferredRect) < rectDistance($1.rect, preferredRect)
           }),
           rectDistance(matchingSnapshot.rect, preferredRect) < 2 {
            return matchingSnapshot
        }

        if let preferredPoint,
           let containingSnapshot = finderSnapshots.first(where: { $0.rect.contains(preferredPoint) }) {
            return containingSnapshot
        }

        return finderSnapshots.max(by: { ($0.rect.width * $0.rect.height) < ($1.rect.width * $1.rect.height) })
    }

    nonisolated static func finderWindowSnapshot(
        windowID: Int,
        fromWindowInfo windowInfo: [[String: Any]],
        screenFrame: NSRect
    ) -> FinderWindowSnapshot? {
        windowInfo.compactMap { snapshot(fromWindowInfoEntry: $0, screenFrame: screenFrame) }
            .first(where: { $0.windowID == windowID })
    }

    nonisolated private static func finderWindowSnapshots(
        fromWindowInfo windowInfo: [[String: Any]],
        finderPID: pid_t,
        screenFrame: NSRect
    ) -> [FinderWindowSnapshot] {
        return windowInfo.compactMap { window -> FinderWindowSnapshot? in
            guard intValue(window[kCGWindowOwnerPID as String]) == Int(finderPID) else { return nil }
            return snapshot(fromWindowInfoEntry: window, screenFrame: screenFrame)
        }
    }

    nonisolated private static func snapshot(fromWindowInfoEntry window: [String: Any], screenFrame: NSRect) -> FinderWindowSnapshot? {
        guard intValue(window[kCGWindowLayer as String]) == 0,
              let windowID = intValue(window[kCGWindowNumber as String]),
              let rawRect = rawWindowRect(fromWindowInfoEntry: window),
              rawRect.width > 0,
              rawRect.height > 0 else {
            return nil
        }

        return FinderWindowSnapshot(
            windowID: windowID,
            rect: appKitRect(fromAccessibilityRect: rawRect, onScreenFrame: screenFrame)
        )
    }

    nonisolated private static func rawWindowRect(fromWindowInfoEntry window: [String: Any]) -> CGRect? {
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        return CGRect(
            x: cgFloatValue(bounds["X"]),
            y: cgFloatValue(bounds["Y"]),
            width: cgFloatValue(bounds["Width"]),
            height: cgFloatValue(bounds["Height"])
        )
    }

    nonisolated private static func rectDistance(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        abs(lhs.origin.x - rhs.origin.x)
            + abs(lhs.origin.y - rhs.origin.y)
            + abs(lhs.size.width - rhs.size.width)
            + abs(lhs.size.height - rhs.size.height)
    }

    nonisolated private static func cgFloatValue(_ value: Any?) -> CGFloat {
        if let number = value as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        if let double = value as? Double {
            return CGFloat(double)
        }
        if let int = value as? Int {
            return CGFloat(int)
        }
        return 0
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }

    private func screenContaining(_ rect: CGRect) -> NSScreen? {
        let probePoint = NSPoint(x: rect.midX, y: rect.origin.y)
        return NSScreen.screens.first(where: { NSPointInRect(probePoint, $0.frame) }) ?? NSScreen.main
    }

    private func refreshFinderWindowRectFromWindowServer() {
        guard let finderApp = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first else {
            activeFinderWindowRect = nil
            return
        }

        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let preferredPoint = NSEvent.mouseLocation
        let screenFrame = NSScreen.screens.first(where: { NSPointInRect(preferredPoint, $0.frame) })?.frame
            ?? NSScreen.main?.frame
            ?? .zero

        let rect = Self.bestFinderWindowRect(
            fromWindowInfo: info,
            finderPID: finderApp.processIdentifier,
            preferredPoint: preferredPoint,
            screenFrame: screenFrame
        )

        logger.debug("Updated Finder window rect via CGWindow fallback appKit=\(String(describing: rect), privacy: .public)")
        activeFinderWindowRect = rect
        activeFinderWindowSnapshot = rect.map { matchedRect in
            Self.bestFinderWindowSnapshot(
                fromWindowInfo: info,
                finderPID: finderApp.processIdentifier,
                preferredRect: matchedRect,
                preferredPoint: preferredPoint,
                preferredWindowID: nil,
                screenFrame: screenFrame
            ) ?? FinderWindowSnapshot(windowID: nil, rect: matchedRect)
        }
    }

    private func registerWorkspaceObservers() {
        let workspace = NSWorkspace.shared.notificationCenter

        if activateObserver == nil {
            activateObserver = workspace.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleWorkspaceActivate(notification)
                }
            }
        }

        if deactivateObserver == nil {
            deactivateObserver = workspace.addObserver(
                forName: NSWorkspace.didDeactivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleWorkspaceDeactivate(notification)
                }
            }
        }

        if terminateObserver == nil {
            terminateObserver = workspace.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleWorkspaceTerminate(notification)
                }
            }
        }
    }
}
