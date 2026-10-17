import AppKit

/// The panel's single Liquid Glass body.
///
/// `tintColor` is copied as a plain color, so the frosted tint is resolved
/// explicitly for the current appearance and re-resolved whenever the system
/// switches between Light and Dark.
final class StashPanelGlassView: NSGlassEffectView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceTint()
    }

    func applyAppearanceTint() {
        tintColor = SideStashGlassPalette.paneTint.resolved(for: effectiveAppearance)
    }
}

@MainActor
enum StashPanelSurfaceFactory {
    static func make(frame: NSRect, contentView: NSView) -> StashPanelGlassView {
        let surface = StashPanelGlassView(frame: frame)
        surface.style = .regular
        surface.cornerRadius = SideStashSidebarStyle.paneCornerRadius
        surface.contentView = contentView
        surface.autoresizingMask = [.width, .height]
        surface.applyAppearanceTint()
        return surface
    }
}
