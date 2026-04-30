import AppKit

@MainActor
class DragDetector {
    static let shared = DragDetector()

    var onDragDetected: ((NSPoint) -> Void)?

    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var trackingTimer: Timer?

    private var dragStartPoint: NSPoint?
    private var detectionStartTime: Date?
    private(set) var isMonitoring = false

    private let dragThreshold: CGFloat = 12.0
    private let maxDetectionInterval: TimeInterval = 1.0
    private let trackingInterval: TimeInterval = 0.03

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDown()
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseUp()
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            mouseUpMonitor = nil
        }
        cancelTracking()
    }

    private func handleMouseDown() {
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        guard frontmostApp?.bundleIdentifier == "com.apple.finder" else { return }

        dragStartPoint = NSEvent.mouseLocation
        detectionStartTime = Date()

        trackingTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDragProgress()
            }
        }
    }

    private func handleMouseUp() {
        cancelTracking()
    }

    private func checkDragProgress() {
        guard let startPoint = dragStartPoint, let startTime = detectionStartTime else {
            cancelTracking()
            return
        }

        if Date().timeIntervalSince(startTime) > maxDetectionInterval {
            cancelTracking()
            return
        }

        let currentPoint = NSEvent.mouseLocation
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)

        if distance >= dragThreshold {
            cancelTracking()
            onDragDetected?(currentPoint)
        }
    }

    private func cancelTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        dragStartPoint = nil
        detectionStartTime = nil
    }
}
