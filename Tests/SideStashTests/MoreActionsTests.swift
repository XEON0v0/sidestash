import Foundation
import Testing
@testable import SideStash

struct MoreActionsTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "MoreActionsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func lastUsed_defaultsToDragAllOut() {
        let memory = MoreActionsMemory(defaults: makeDefaults())
        #expect(memory.lastUsed == .dragAllOut)
    }

    @Test func lastUsed_remembersTheRecordedAction() {
        let defaults = makeDefaults()
        MoreActionsMemory(defaults: defaults).record(.exportArchive)

        #expect(MoreActionsMemory(defaults: defaults).lastUsed == .exportArchive)

        MoreActionsMemory(defaults: defaults).record(.systemShare)
        #expect(MoreActionsMemory(defaults: defaults).lastUsed == .systemShare)
    }

    @Test func lastUsed_neverBecomesTheFormatConversionPlaceholder() {
        let defaults = makeDefaults()
        let memory = MoreActionsMemory(defaults: defaults)
        memory.record(.exportArchive)
        memory.record(.convertFormat)
        #expect(memory.lastUsed == .exportArchive)

        // Even a stale stored value falls back.
        defaults.set(SideStashMoreAction.convertFormat.rawValue, forKey: MoreActionsMemory.defaultsKey)
        #expect(memory.lastUsed == .dragAllOut)
        defaults.set("removedAction", forKey: MoreActionsMemory.defaultsKey)
        #expect(memory.lastUsed == .dragAllOut)
    }

    @Test func availability_needsFilesAndAnImplementation() {
        for action in SideStashMoreAction.allCases where action.isImplemented {
            #expect(action.availability(hasItems: true) == .enabled)
            #expect(action.availability(hasItems: false) == .disabled(reasonKey: "bulk.unavailable.empty"))
        }
        #expect(!SideStashMoreAction.convertFormat.isImplemented)
        #expect(SideStashMoreAction.convertFormat.availability(hasItems: true)
            == .disabled(reasonKey: "more.convert.unavailable"))
    }

    @Test func everyMoreActionStringIsLocalized() throws {
        var keys = ["more.menu.title", "more.section.share", "more.drag_all.hint",
                    "more.archive.result.success", "more.archive.result.failure",
                    "more.convert.unavailable"]
        for action in SideStashMoreAction.allCases {
            keys.append(action.titleKey)
            keys.append(action.shortTitleKey)
        }

        for localizationName in ["en", "zh-Hans"] {
            let localizationURL = try #require(Bundle.module.url(forResource: localizationName, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: localizationURL))
            for key in keys {
                #expect(bundle.localizedString(forKey: key, value: nil, table: nil) != key, "\(localizationName): \(key)")
            }
        }
    }
}
