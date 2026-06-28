import SwiftUI
import AppKit

struct GlassBackgroundView: NSViewRepresentable {
    var cornerRadius: CGFloat = FileStashSidebarStyle.paneCornerRadius

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26, *) {
            let glassView = NSGlassEffectView()
            glassView.cornerRadius = cornerRadius
            glassView.style = .regular
            return glassView
        } else {
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .sidebar
            visualEffectView.blendingMode = .withinWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = cornerRadius
            return visualEffectView
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26, *) {
            guard let glassView = nsView as? NSGlassEffectView else { return }
            glassView.cornerRadius = cornerRadius
        } else {
            guard let visualEffectView = nsView as? NSVisualEffectView else { return }
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = cornerRadius
        }
    }
}
