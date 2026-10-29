import Foundation

/// Actions behind the header pill's `…` menu. They work on every stashed
/// file at once; the pill's leading segment repeats the last one used.
enum SideStashMoreAction: String, CaseIterable, Hashable {
    /// Drag every stashed file out in one session, e.g. into an upload area.
    case dragAllOut
    /// Share every stashed file through the system share picker.
    case systemShare
    /// Zip every stashed file into the current Finder folder.
    case exportArchive
    /// Placeholder, not implemented yet.
    case convertFormat

    var symbolName: String {
        switch self {
        case .dragAllOut:
            return "square.stack.3d.up"
        case .systemShare:
            return "square.and.arrow.up"
        case .exportArchive:
            return "doc.zipper"
        case .convertFormat:
            return "arrow.triangle.2.circlepath"
        }
    }

    /// Full title shown in the menu.
    var titleKey: String {
        switch self {
        case .dragAllOut:
            return "more.drag_all.title"
        case .systemShare:
            return "more.share.title"
        case .exportArchive:
            return "more.archive.title"
        case .convertFormat:
            return "more.convert.title"
        }
    }

    /// Short label shown in the pill's leading segment.
    var shortTitleKey: String {
        switch self {
        case .dragAllOut:
            return "more.drag_all.short"
        case .systemShare:
            return "more.share.short"
        case .exportArchive:
            return "more.archive.short"
        case .convertFormat:
            return "more.convert.short"
        }
    }

    var isImplemented: Bool {
        self != .convertFormat
    }

    func availability(hasItems: Bool) -> SideStashBottomActionAvailability {
        guard isImplemented else {
            return .disabled(reasonKey: "more.convert.unavailable")
        }
        guard hasItems else {
            return .disabled(reasonKey: "bulk.unavailable.empty")
        }
        return .enabled
    }
}

/// Remembers the last more-action used, so the pill can offer it again.
struct MoreActionsMemory {
    static let defaultsKey = "moreActions.lastUsed"
    static let fallback: SideStashMoreAction = .dragAllOut

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastUsed: SideStashMoreAction {
        guard
            let rawValue = defaults.string(forKey: Self.defaultsKey),
            let action = SideStashMoreAction(rawValue: rawValue),
            action.isImplemented
        else {
            return Self.fallback
        }
        return action
    }

    /// Unimplemented actions are never remembered.
    func record(_ action: SideStashMoreAction) {
        guard action.isImplemented else { return }
        defaults.set(action.rawValue, forKey: Self.defaultsKey)
    }
}
