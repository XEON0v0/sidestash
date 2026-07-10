import SwiftUI

enum SideStashBottomActionAvailability: Equatable {
    case enabled
    case disabled(reasonKey: String)

    var isEnabled: Bool {
        switch self {
        case .enabled:
            return true
        case .disabled:
            return false
        }
    }

    var reasonKey: String? {
        switch self {
        case .enabled:
            return nil
        case let .disabled(reasonKey):
            return reasonKey
        }
    }
}

extension SideStashBulkAction {
    func availability(
        hasItems: Bool,
        hasRestorableItems: Bool
    ) -> SideStashBottomActionAvailability {
        guard hasItems else {
            return .disabled(reasonKey: "bulk.unavailable.empty")
        }

        if self == .restoreAll, !hasRestorableItems {
            return .disabled(reasonKey: "bulk.restore.unavailable")
        }

        return .enabled
    }
}

struct BottomActionInteractionState: Equatable {
    private(set) var hoveredAction: SideStashBulkAction?
    private(set) var tooltipAction: SideStashBulkAction?

    @discardableResult
    mutating func enter(_ action: SideStashBulkAction) -> Bool {
        hoveredAction = action

        guard tooltipAction == nil else {
            tooltipAction = action
            return false
        }

        return true
    }

    mutating func reveal(_ action: SideStashBulkAction) {
        guard hoveredAction == action else { return }
        tooltipAction = action
    }

    mutating func leaveToolbar() {
        hoveredAction = nil
        tooltipAction = nil
    }

    static func action(
        at horizontalPosition: CGFloat,
        buttonWidth: CGFloat
    ) -> SideStashBulkAction? {
        guard horizontalPosition >= 0, buttonWidth > 0 else { return nil }

        let actions = SideStashBulkAction.allCases
        let index = Int(horizontalPosition / buttonWidth)
        guard actions.indices.contains(index) else { return nil }
        return actions[index]
    }
}

struct BottomActionToolbar: View {
    @Environment(\.colorScheme) private var colorScheme

    let hasItems: Bool
    let hasRestorableItems: Bool
    let perform: (SideStashBulkAction) -> Void

    @State private var interaction = BottomActionInteractionState()
    @State private var tooltipTask: Task<Void, Never>?

    private var toolbarWidth: CGFloat {
        SideStashSidebarChromePolicy.bottomActionButtonWidth
            * CGFloat(SideStashBulkAction.allCases.count)
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: SideStashSidebarChromePolicy.bottomActionsTooltipGap) {
                toolbarLayout
            }
        } else {
            toolbarLayout
        }
    }

    private var toolbarLayout: some View {
        ZStack(alignment: .bottom) {
            if let tooltipAction = interaction.tooltipAction {
                tooltip(for: tooltipAction)
                    .padding(
                        .bottom,
                        SideStashSidebarChromePolicy.bottomActionsHeight
                            + SideStashSidebarChromePolicy.bottomActionsTooltipGap
                    )
                    .transition(.opacity.combined(with: .offset(y: 4)))
                    .zIndex(1)
            }

            toolbarSurface
        }
        .frame(
            width: SideStashSidebarChromePolicy.bottomActionsTooltipMaxWidth,
            height: SideStashSidebarChromePolicy.bottomActionsOverlayHeight,
            alignment: .bottom
        )
        .animation(.easeOut(duration: 0.12), value: interaction.tooltipAction)
        .onDisappear {
            clearInteraction()
        }
    }

    @ViewBuilder
    private var toolbarSurface: some View {
        Group {
            if #available(macOS 26.0, *) {
                buttonRow
                    .background {
                        Capsule()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.035))
                            .allowsHitTesting(false)
                    }
                    .glassEffect(.regular.interactive(), in: Capsule())
            } else {
                buttonRow
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .overlay {
            Capsule()
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.24 : 0.72),
                    lineWidth: 1
                )
                .overlay {
                    Capsule()
                        .stroke(
                            Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10),
                            lineWidth: 1
                        )
                }
                .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.28 : 0.16),
            radius: 12,
            y: 6
        )
    }

    private var buttonRow: some View {
        HStack(spacing: 0) {
            ForEach(SideStashBulkAction.allCases, id: \.self) { action in
                actionControl(action)
            }
        }
        .frame(
            width: toolbarWidth,
            height: SideStashSidebarChromePolicy.bottomActionsHeight
        )
        .contentShape(Capsule())
        .onContinuousHover { phase in
            switch phase {
            case let .active(location):
                guard let action = BottomActionInteractionState.action(
                    at: location.x,
                    buttonWidth: SideStashSidebarChromePolicy.bottomActionButtonWidth
                ) else {
                    clearInteraction()
                    return
                }
                actionEntered(action)

            case .ended:
                clearInteraction()
            }
        }
    }

    private func actionControl(_ action: SideStashBulkAction) -> some View {
        let availability = action.availability(
            hasItems: hasItems,
            hasRestorableItems: hasRestorableItems
        )
        let title = NSLocalizedString(action.titleKey, comment: "Bulk action purpose")

        return ZStack {
            Button {
                clearInteraction()
                perform(action)
            } label: {
                Image(systemName: action.symbolName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(
                        size: SideStashSidebarChromePolicy.bottomActionsIconSize,
                        weight: .medium
                    ))
                    .frame(
                        width: SideStashSidebarChromePolicy.bottomActionButtonWidth,
                        height: SideStashSidebarChromePolicy.bottomActionsHeight
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(BottomActionButtonStyle(
                isHovered: interaction.hoveredAction == action
            ))
            .disabled(!availability.isEnabled)
            .accessibilityLabel(Text(title))
        }
        .frame(
            width: SideStashSidebarChromePolicy.bottomActionButtonWidth,
            height: SideStashSidebarChromePolicy.bottomActionsHeight
        )
        .contentShape(Rectangle())
        .help(helpText(for: action, availability: availability))
    }

    @ViewBuilder
    private func tooltip(for action: SideStashBulkAction) -> some View {
        if #available(macOS 26.0, *) {
            tooltipContent(for: action)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(
                        cornerRadius: SideStashSidebarChromePolicy.bottomActionsTooltipCornerRadius,
                        style: .continuous
                    )
                )
        } else {
            tooltipContent(for: action)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(
                        cornerRadius: SideStashSidebarChromePolicy.bottomActionsTooltipCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: SideStashSidebarChromePolicy.bottomActionsTooltipCornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.62),
                        lineWidth: 1
                    )
                }
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        }
    }

    private func tooltipContent(for action: SideStashBulkAction) -> some View {
        let availability = action.availability(
            hasItems: hasItems,
            hasRestorableItems: hasRestorableItems
        )

        return VStack(spacing: 2) {
            Text(NSLocalizedString(action.titleKey, comment: "Bulk action purpose"))
                .font(.system(size: 12, weight: .semibold))

            if let reasonKey = availability.reasonKey {
                Text(NSLocalizedString(reasonKey, comment: "Bulk action unavailable reason"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .allowsHitTesting(false)
    }

    private func helpText(
        for action: SideStashBulkAction,
        availability: SideStashBottomActionAvailability
    ) -> String {
        let title = NSLocalizedString(action.titleKey, comment: "Bulk action purpose")
        guard let reasonKey = availability.reasonKey else { return title }
        let reason = NSLocalizedString(reasonKey, comment: "Bulk action unavailable reason")
        return "\(title) - \(reason)"
    }

    private func actionEntered(_ action: SideStashBulkAction) {
        guard interaction.hoveredAction != action else { return }

        tooltipTask?.cancel()
        tooltipTask = nil

        guard interaction.enter(action) else { return }

        tooltipTask = Task { @MainActor in
            let delay = SideStashSidebarChromePolicy.bottomActionsTooltipDelay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            interaction.reveal(action)
        }
    }

    private func clearInteraction() {
        tooltipTask?.cancel()
        tooltipTask = nil
        interaction.leaveToolbar()
    }
}

private struct BottomActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isEmphasized = isEnabled && (isHovered || configuration.isPressed)
        let scale: CGFloat
        if configuration.isPressed, isEnabled {
            scale = SideStashSidebarChromePolicy.bottomActionPressedScale
        } else if isHovered, isEnabled {
            scale = SideStashSidebarChromePolicy.bottomActionHoverScale
        } else {
            scale = 1
        }

        return configuration.label
            .foregroundStyle(.primary.opacity(
                isEnabled
                    ? SideStashSidebarChromePolicy.bottomActionsEnabledIconOpacity
                    : SideStashSidebarChromePolicy.bottomActionsDisabledIconOpacity
            ))
            .background {
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.48))
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                    .opacity(isEmphasized ? 1 : 0)
            }
            .scaleEffect(scale)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
