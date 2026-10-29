import AppKit

/// A color with explicit Light and Dark variants.
///
/// AppKit layers resolve it against a view's `effectiveAppearance` and must
/// re-apply it from `viewDidChangeEffectiveAppearance()`, because a `CGColor`
/// never updates on its own. `draw(_:)` and SwiftUI can use `dynamic`, which
/// AppKit re-resolves whenever the appearance changes.
struct SideStashAdaptiveColor: Sendable {
    let light: @Sendable () -> NSColor
    let dark: @Sendable () -> NSColor

    /// Concrete sRGB color for `appearance`. System colors inside a variant
    /// (window background, accent) resolve under that appearance too.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var color = NSColor.clear
        appearance.performAsCurrentDrawingAppearance {
            let variant = appearance.isDarkGlassAppearance ? dark() : light()
            color = variant.usingColorSpace(.sRGB) ?? variant
        }
        return color
    }

    func cgColor(for appearance: NSAppearance) -> CGColor {
        resolved(for: appearance).cgColor
    }

    var dynamic: NSColor {
        NSColor(name: nil) { appearance in
            resolved(for: appearance)
        }
    }
}

extension NSAppearance {
    /// True for Dark Aqua and its vibrant and high-contrast variants.
    var isDarkGlassAppearance: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

/// Light/dark color tokens for the Liquid Glass panel. The glass itself and
/// SwiftUI semantic styles adapt automatically; these cover the few custom
/// fills AppKit draws on top of it.
enum SideStashGlassPalette {
    /// Frosted tint for the panel's `NSGlassEffectView`.
    static let paneTint = SideStashAdaptiveColor(
        light: { NSColor.windowBackgroundColor.withAlphaComponent(0.28) },
        dark: { NSColor.windowBackgroundColor.withAlphaComponent(0.12) }
    )

    // Each file's plate sits one step brighter than the panel, brighter still
    // on hover. Dark glass brightens with a white tint; light glass turns gray
    // under any tint, so it gets a white wash on top of the glass instead.

    static let rowGlassTint = SideStashAdaptiveColor(
        light: { NSColor.clear },
        dark: { NSColor.white.withAlphaComponent(0.10) }
    )

    static let rowGlassHoverTint = SideStashAdaptiveColor(
        light: { NSColor.clear },
        dark: { NSColor.white.withAlphaComponent(0.26) }
    )

    static let rowPlateWash = SideStashAdaptiveColor(
        light: { NSColor.white.withAlphaComponent(0.50) },
        dark: { NSColor.clear }
    )

    static let rowPlateHoverWash = SideStashAdaptiveColor(
        light: { NSColor.white.withAlphaComponent(0.72) },
        dark: { NSColor.clear }
    )

    /// Drop target highlight, following the user's accent color.
    static let dropTargetFill = SideStashAdaptiveColor(
        light: { NSColor.controlAccentColor.withAlphaComponent(0.10) },
        dark: { NSColor.controlAccentColor.withAlphaComponent(0.16) }
    )

    static let dropTargetStroke = SideStashAdaptiveColor(
        light: { NSColor.controlAccentColor.withAlphaComponent(0.45) },
        dark: { NSColor.controlAccentColor.withAlphaComponent(0.55) }
    )

    /// Strip shown on the Finder-facing edge during the attached reveal.
    static let edgePreviewFill = SideStashAdaptiveColor(
        light: { NSColor.black.withAlphaComponent(0.04) },
        dark: { NSColor.white.withAlphaComponent(0.06) }
    )

    static let edgePreviewAccent = SideStashAdaptiveColor(
        light: { NSColor.black.withAlphaComponent(0.12) },
        dark: { NSColor.white.withAlphaComponent(0.18) }
    )

    /// Hairline between the header pill's two segments: just enough to
    /// separate them without cutting the glass in half.
    static let pillDivider = SideStashAdaptiveColor(
        light: { NSColor.black.withAlphaComponent(0.10) },
        dark: { NSColor.white.withAlphaComponent(0.20) }
    )
}
