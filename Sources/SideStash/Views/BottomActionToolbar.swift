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
}
