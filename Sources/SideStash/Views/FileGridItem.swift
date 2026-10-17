import SwiftUI

enum FileRowPlateStyle {
    static let hoverScale: CGFloat = 1.01
    static let pressedScale: CGFloat = 0.985
    static let hoverAnimationDuration: TimeInterval = 0.15
    static let pressAnimationDuration: TimeInterval = 0.08

    /// Dragging out wins over pressing, pressing over hovering. The lift
    /// matches the AppKit row's own lift so plate and content move together.
    static func scale(for interaction: FileRowInteraction) -> CGFloat {
        if interaction.isLifted {
            return InteractionMotionStyle.dragLiftScale
        }
        if interaction.isPressed {
            return pressedScale
        }
        if interaction.isHovered {
            return hoverScale
        }
        return 1
    }

    static func opacity(for interaction: FileRowInteraction) -> Double {
        interaction.isLifted ? InteractionMotionStyle.dragLiftAlpha : 1
    }
}

/// A stashed file on its own Liquid Glass plate, behind the AppKit row (icon,
/// name, drag-out). The file's icon is a light source in the shared
/// `GlassLightingScene`, and the plate's rim is lit by that scene. Rows stay
/// out of a GlassEffectContainer so the plate never covers the row content.
struct FileGridItem: View {
    @EnvironmentObject var store: StashStore
    @Environment(\.glassLightingScene) private var lightingScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: StashItem

    @State private var interaction = FileRowInteraction()

    var body: some View {
        DraggableFileItem(item: item, store: store) { interaction = $0 }
            .frame(height: SideStashSidebarStyle.rowHeight)
            .background { plate }
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .named(GlassLightingSpace.name))
                return CGPoint(x: frame.minX + SideStashSidebarStyle.rowIconCenterX, y: frame.midY)
            } action: { iconCenter in
                lightingScene?.setEmitter(id: item.id, position: iconCenter, light: item.light)
            }
            .onDisappear {
                lightingScene?.removeEmitter(id: item.id)
            }
    }

    private var plate: some View {
        Color.clear
            .glassEffect(plateGlass, in: plateShape)
            .overlay {
                plateShape.fill(Color(nsColor: plateWash.dynamic))
            }
            .overlay {
                GlassRim(shape: .roundedRect(cornerRadius: SideStashSidebarStyle.rowCornerRadius), kind: .plate)
            }
            .scaleEffect(reduceMotion ? 1 : FileRowPlateStyle.scale(for: interaction))
            .opacity(FileRowPlateStyle.opacity(for: interaction))
            .animation(.easeOut(duration: FileRowPlateStyle.hoverAnimationDuration), value: interaction.isHovered)
            .animation(.easeOut(duration: FileRowPlateStyle.pressAnimationDuration), value: interaction.isPressed)
            .animation(.easeOut(duration: InteractionMotionStyle.dragLiftDuration), value: interaction.isLifted)
    }

    private var plateShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SideStashSidebarStyle.rowCornerRadius, style: .continuous)
    }

    /// Plates sit one step brighter than the panel, and brighter still on hover
    /// (see `SideStashGlassPalette` for why light and dark lift differently).
    private var plateGlass: Glass {
        let tint = interaction.isHovered
            ? SideStashGlassPalette.rowGlassHoverTint
            : SideStashGlassPalette.rowGlassTint
        return .regular.tint(Color(nsColor: tint.dynamic))
    }

    private var plateWash: SideStashAdaptiveColor {
        interaction.isHovered
            ? SideStashGlassPalette.rowPlateHoverWash
            : SideStashGlassPalette.rowPlateWash
    }
}
