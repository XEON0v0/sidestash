import AppKit
import Testing
@testable import SideStash

@MainActor
struct AppearanceAdaptiveViewsTests {
    private let light = NSAppearance(named: .aqua)!
    private let dark = NSAppearance(named: .darkAqua)!

    @Test func row_reportsHoverPressAndLiftWithoutPaintingItsLayer() throws {
        let row = DraggableFileItemView(frame: NSRect(x: 0, y: 0, width: 296, height: 44))
        var reported: [FileRowInteraction] = []
        row.onInteractionChanged = { reported.append($0) }

        row.setHovered(true)
        row.mouseDown(with: try mouseEvent(.leftMouseDown))
        row.setLifted(true)
        row.setLifted(false)
        row.mouseUp(with: try mouseEvent(.leftMouseUp))
        row.setHovered(false)

        #expect(reported == [
            FileRowInteraction(isHovered: true),
            FileRowInteraction(isHovered: true, isPressed: true),
            FileRowInteraction(isHovered: true, isLifted: true),
            FileRowInteraction(isHovered: true),
            FileRowInteraction(),
        ])
        // The glass plate behind the row is SwiftUI's; the row itself stays clear.
        #expect(row.layer?.backgroundColor?.alpha ?? 0 == 0)
    }

    @Test func rowLabel_followsTheAppearanceItIsDrawnIn() throws {
        let row = DraggableFileItemView(frame: NSRect(x: 0, y: 0, width: 296, height: 44))
        let label = try #require(row.subviews.compactMap { $0 as? NSTextField }.first)
        let textColor = try #require(label.textColor)

        var lightBrightness: CGFloat = 0
        var darkBrightness: CGFloat = 0
        light.performAsCurrentDrawingAppearance {
            lightBrightness = textColor.usingColorSpace(.sRGB)?.brightnessComponent ?? 1
        }
        dark.performAsCurrentDrawingAppearance {
            darkBrightness = textColor.usingColorSpace(.sRGB)?.brightnessComponent ?? 0
        }

        // Dark text on light glass, light text on dark glass.
        #expect(lightBrightness < 0.3)
        #expect(darkBrightness > 0.7)
    }

    @Test func row_releasesPressOnMouseUp() throws {
        let row = DraggableFileItemView(frame: NSRect(x: 0, y: 0, width: 296, height: 44))

        row.mouseDown(with: try mouseEvent(.leftMouseDown))
        #expect(row.interaction.isPressed)

        row.mouseUp(with: try mouseEvent(.leftMouseUp))
        #expect(!row.interaction.isPressed)
    }

    @Test func rowHover_tracksWhileTheAppIsInactive() throws {
        let row = DraggableFileItemView(frame: NSRect(x: 0, y: 0, width: 296, height: 44))

        row.updateTrackingAreas()

        let options = try #require(row.trackingAreas.first?.options)
        #expect(options.contains(.activeAlways))
        #expect(options.contains(.mouseEnteredAndExited))
    }

    @Test func rowLabel_truncatesLongNamesInsideTheRow() throws {
        let row = DraggableFileItemView(frame: NSRect(x: 0, y: 0, width: 296, height: 44))
        let name = String(repeating: "a very long file name ", count: 12) + "final.pdf"
        row.item = StashItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            icon: NSImage(size: NSSize(width: 32, height: 32)),
            light: nil,
            originalURL: nil
        )
        let label = try #require(row.subviews.compactMap { $0 as? NSTextField }.first)

        row.layoutSubtreeIfNeeded()

        #expect(label.frame.maxX <= row.bounds.width)
        #expect(label.contentCompressionResistancePriority(for: .horizontal) < .defaultHigh)
        #expect(label.lineBreakMode == .byTruncatingMiddle)
        #expect(row.toolTip == name)
    }

    @Test func dropHighlight_followsTheAccentColorInBothAppearances() {
        let dropZone = DropZoneNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 420))

        dropZone.appearance = light
        dropZone.setDraggingOver(true)
        #expect(matches(dropZone.layer?.backgroundColor, SideStashGlassPalette.dropTargetFill.resolved(for: light)))
        #expect(matches(dropZone.layer?.borderColor, SideStashGlassPalette.dropTargetStroke.resolved(for: light)))
        #expect(dropZone.layer?.borderWidth == 1)

        dropZone.appearance = dark
        dropZone.viewDidChangeEffectiveAppearance()
        #expect(matches(dropZone.layer?.backgroundColor, SideStashGlassPalette.dropTargetFill.resolved(for: dark)))
        #expect(matches(dropZone.layer?.borderColor, SideStashGlassPalette.dropTargetStroke.resolved(for: dark)))

        dropZone.setDraggingOver(false)
        #expect(dropZone.layer?.backgroundColor?.alpha == 0)
        #expect(dropZone.layer?.borderWidth == 0)
    }

    @Test func dropZone_reportsThePointerInSceneCoordinates() throws {
        let dropZone = DropZoneNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 420))
        var reported: [CGPoint?] = []
        dropZone.onPointerMoved = { reported.append($0) }

        dropZone.mouseMoved(with: try mouseEvent(.mouseMoved, at: NSPoint(x: 10, y: 400)))
        dropZone.mouseExited(with: try enterExitEvent(.mouseExited))

        // AppKit's bottom-left origin becomes the scene's top-left origin.
        #expect(reported == [CGPoint(x: 10, y: 20), nil])
    }

    @Test func dropZone_tracksThePointerWhileTheAppIsInactive() throws {
        let dropZone = DropZoneNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 420))

        dropZone.updateTrackingAreas()

        let options = try #require(dropZone.trackingAreas.first?.options)
        #expect(options.contains(.mouseMoved))
        #expect(options.contains(.mouseEnteredAndExited))
        #expect(options.contains(.activeAlways))
    }

    @Test func dropZone_clipsToThePanelGlassShape() {
        let dropZone = DropZoneNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 420))

        #expect(dropZone.layer?.cornerRadius == SideStashSidebarStyle.paneCornerRadius)
        #expect(dropZone.layer?.cornerCurve == .continuous)
        #expect(dropZone.layer?.masksToBounds == true)
    }

    private func enterExitEvent(_ type: NSEvent.EventType) throws -> NSEvent {
        try #require(NSEvent.enterExitEvent(
            with: type,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            trackingNumber: 0,
            userData: nil
        ))
    }

    private func mouseEvent(_ type: NSEvent.EventType, at location: NSPoint = .zero) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ))
    }

    private func matches(_ cgColor: CGColor?, _ expected: NSColor) -> Bool {
        guard let cgColor,
              let actual = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB),
              let expected = expected.usingColorSpace(.sRGB) else {
            return false
        }

        return abs(actual.redComponent - expected.redComponent) < 0.002
            && abs(actual.greenComponent - expected.greenComponent) < 0.002
            && abs(actual.blueComponent - expected.blueComponent) < 0.002
            && abs(actual.alphaComponent - expected.alphaComponent) < 0.002
    }
}
