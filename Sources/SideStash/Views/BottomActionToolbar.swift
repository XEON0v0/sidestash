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
