
## Task 3 — Atomic metadata write + safe FileManager URL

- `FileManager.default.replaceItemAt()` in Swift 6.2 does NOT take a `resultingItemURL:` parameter (that was the old Objective-C API). Signature: `replaceItemAt(_:withItemAt:backupItemName:options:) throws -> URL?`
- `data.write(to:options: .atomic)` on temp file provides the atomicity guarantee at the file system level; `replaceItemAt` swaps the inode atomically
- Force-unwrapped `.first!` from `FileManager.default.urls()` was at line 22-25 — replaced with `guard let` + `homeDirectoryForCurrentUser` fallback
- Caching `stashDirectory` via `_stashDirectory: URL?` stored property avoids redundant filesystem lookups on each access

## Task 4 — Remove dead code `unstash(item:)`

- `func unstash(item: StashItem)` at lines 148-160 was dead code — it deleted the stashed file via `FileManager.default.removeItem(at:)` without restoring it to its original location
- Not called from any view. The actual restore logic is in `finalizeDrag(item:)` which checks if Finder moved the file out and restores if not
- Removal confirmed: grep for "unstash" across Sources/ returns nothing beyond the method definition and an unrelated print message on line 133

## 2026-04-30: Task 5 — Path duplication dedup

- `StashStore.stashDirectory` was `private`, preventing `AppDelegate` from using it directly
- Changed to `internal` (implicit default by removing `private`) — safe since `_stashDirectory` stored property remains `private`
- `AppDelegate.openStashFolder()` now uses `StashStore.shared.stashDirectory` directly, eliminating duplicate path construction
- Verified: no `applicationSupportDirectory` references remain in AppDelegate.swift, build passes

## 2026-04-30: Task 12 — Icon caching in StashStore

- Added `private var iconCache: [String: NSImage] = [:]` to `StashStore`
- Cache key is `url.path`, matching `StashItem.id` pattern
- In `refreshItems()`, checks cache before calling `NSWorkspace.shared.icon(forFile:)`; stores newly loaded icons at 48x48
- Stale entries removed after building items array via `iconCache.filter { currentPaths.contains($0.key) }` where `currentPaths = Set(items.map(\.id))`
- No LRU, no memory pressure handling, no thread-safety needed (StashStore is @MainActor)
- Build verified clean

## 2026-04-30: Magic Number Extraction (T2)

**Files modified:**
- `StashWindowManager.swift` — Added `private enum Layout` with `panelWidth`, `panelHeight`, `panelOffset`. Replaced 6 magic number usages across 3 methods.
- `DraggableFileItem.swift` — Added `private enum Layout` with `cornerRadius`, `borderWidth`, `iconSize`, `iconTopPadding`, `labelTopPadding`, `labelHorizontalPadding`, `labelFontSize`. Replaced 11 magic number usages in `commonInit()`.
- `StashContentView.swift` — Added `private enum Layout` with `closeButtonSize`, `closeButtonFontSize`, `headerFontSize`, `headerPadding`, `headerVerticalPadding`. Replaced 5 magic number usages in `header` property.

**Approach:** Inline `private enum Layout` per class (not file-level) — keeps constants scoped near their usage, no new file needed.

**Gotchas:**
- `cornerRadius(16)` on the ZStack in StashContentView was left as-is (only visual, not a layout dimension).
- `.frame(width: 300, height: 420)` on the content view was also left as-is since it mirrors the panel size defined in StashWindowManager.
- No value changes — pure extraction.

## 2026-04-30: Replace try? with do/catch + os.Logger (T11)

**Files modified:**
- `StashStore.swift` — Added `import OSLog`, `private let logger = Logger(subsystem: "com.ray.FileStash", category: "StashStore")`. Replaced 9 `try?` occurrences with `do/catch` blocks logging via `logger.error(...)`.
- `StashStoreTests.swift` — Added 3 error-behavior tests: `loadMetadata_whenFileMissing_returnsEmpty`, `saveMetadata_roundTrip_restoresOriginalPath`, `stash_withNonexistentSource_failsGracefully`.

**try? replacements (9 total):**
1. `ensureDirectoryExists()` — `try? createDirectory` → `do { try createDirectory } catch { logger.error(...) }`
2-3. `loadMetadata()` — `try? Data(contentsOf:)` + `try? JSONSerialization.jsonObject` → two `do/catch` blocks with early return
4-5. `saveMetadata()` — `try? JSONSerialization.data` + fallback `try? write` → `do/catch` for both paths
6. `refreshItems()` — `try? contentsOfDirectory` → `do/catch` with items = []
7. `stash()` — `try? removeItem` after copy fallback → `do/catch` with logger
8. `finalizeDrag()` (async polling, T9/T10) — `try? await Task.sleep` → `do/catch` with logger + break
9. `finalizeDrag()` (timeout restore, T9/T10) — `try? createDirectory` → `do/catch` with logger

**Gotchas:**
- T9/T10 ran concurrently and modified `finalizeDrag()` from `dispatchAfter` to `Task`-based polling while this task was in progress. Two additional `try?` (Task.sleep, createDirectory) appeared after initial replacement. Re-read the file after build to catch them.
- `_Testing_Foundation` module conflict: adding `import Foundation` to the test file alongside `import Testing` causes `no such module '_Testing_Foundation'` error. Solution: remove `import Foundation` from test file — `import Testing` provides Foundation types via its `_Testing_Foundation` overlay.
- `swift test` exits with code 0 but produces no test output on CLT-only macOS. XCTest.framework unavailable; test binary is MH_BUNDLE type which needs a test host to load. Tests compile but cannot execute without Xcode. Verified via `swift build --build-tests` success.
## T8: uniqueURL dedup + self-stash guard

### Changes made
- `uniqueDestinationURL(for:)` now delegates to `uniqueURL(at: stashDirectory, for:)` — removed 12 duplicate lines
- `stash(url:)` now has guard at top: `guard !sourceURL.path.hasPrefix(stashDirectory.path)`

### Test runner issue
- XCTest.framework not available on this CLT-only system (no Xcode)
- Swift Testing runner defaults to "xctest" which is `#if false`'d — no tests execute
- `--enable-swift-testing` enables build-time support but doesn't change runner default
- Workaround (modify generated runner.swift to `return "swift-testing"`) works but file is regenerated on clean
- Tests compile cleanly — all 10 `@Test` methods pass compilation

### Files modified
- `Sources/FileStash/StashStore.swift` — dedup (lines 217-219) + guard (lines 132-136)
- `Tests/FileStashTests/TestHelpers.swift` — added `makeNonexistentFileURL()` helper (avoids Foundation import in test file)
- `Tests/FileStashTests/StashStoreTests.swift` — fixed `stash_withNonexistentSource_failsGracefully` to use helper (lines 123-124)

## DI: Inject StashStore via dependency injection

### Files modified
- `AppDelegate.swift` — Creates `store: StashStore` instance, creates `windowManager: StashWindowManager(store:)`, replaces all `StashWindowManager.shared.xxx` with `windowManager.xxx`, replaces `StashStore.shared.stashDirectory` with `store.stashDirectory`
- `StashWindowManager.swift` — Added `init(store: StashStore)`, `private let store: StashStore`, replaced all `StashStore.shared.refreshItems()` with `store.refreshItems()`, sets `dropZone.store = store` in `ensurePanelCreated()`
- `DropZoneView.swift` — Added `var store: StashStore?`, replaced `StashStore.shared.stash(url:)` with `store?.stash(url:)`
- `DraggableFileItem.swift` — Added `let store: StashStore` to `DraggableFileItem` struct, added `var store: StashStore?` to `DraggableFileItemView`, replaced `StashStore.shared.finalizeDrag` with `self.store?.finalizeDrag` (required explicit `self.` in `DispatchQueue.main.async` closure)
- `FileGridItem.swift` — Added `@EnvironmentObject var store: StashStore`, passes `store` to `DraggableFileItem(item:store:)`

### Approach
- `StashStore.shared` kept for fallback (static let still exists)
- `StashWindowManager.shared` kept for fallback (creates its own StashStore)
- Store flows AppDelegate → StashWindowManager → DropZoneNSView (via property) + StashContentView (via `.environmentObject`) → FileGridItem (via `@EnvironmentObject`) → DraggableFileItem (via init param) → DraggableFileItemView (via property)
- Required `override init()` in AppDelegate to initialize `windowManager` with `store` before `super.init()`

### Gotchas
- `DispatchQueue.main.async` closure in `DraggableFileItemView` required `self.store` (explicit self) since `store` is an instance property captured in a non-`@MainActor` closure
- AppDelegate property initialization order: `store` must be declared before `windowManager` since `windowManager` depends on it
- Used `[weak self]` in `onDragDetected` closure capture to avoid retain cycle (though AppDelegate is effectively app-lifetime singleton)

## T14 — Add .lproj copy to build_app.sh

- Added `cp -R` for both `en.lproj` and `zh-Hans.lproj` from `Sources/FileStash/` into `Contents/Resources/` inside the .app bundle
- Placed the copy commands right after `mkdir -p "${APP_BUNDLE}/Contents/Resources"` and before the binary copy
- Verified: `./build_app.sh` runs cleanly, both `.lproj` dirs present in the built bundle

## F3: Manual QA — 2026-04-30

### Results
- Release build: PASS (exit 0, 29.42s)
- App bundle: PASS
  - Binary: FileStash.app/Contents/MacOS/FileStash ✓
  - en.lproj: 4 entries ✓
  - zh-Hans.lproj: 4 entries ✓
  - AppIcon.icns: generated ✓
  - BUNDLE_ID: com.ray.FileStash ✓
- Debug build: PASS (exit 0, 30.63s)
- Test compilation: PASS (exit 0)
- Git state: 2 commits, .gitignore with proper entries ✓
- Localization: 4 entries per locale, no hardcoded Chinese in Swift ✓
- LSP diagnostics: 0 errors across 10 files ✓

## F4 — Scope Fidelity Check (2026-04-30)

- VERDICT: REJECT — T11 missing MockFileSystemProvider (blocking), 4 tasks partially compliant
- 10/15 fully compliant, 4 partial, 1 non-compliant
- Cross-task contamination: CLEAN
- Unaccounted files: 1 (TestHelpers.swift)
- Key gaps: MockFileSystemProvider not created, 3 print() remain in StashStore, .attrib flag missing from file watcher, some magic numbers unextracted in StashContentView
- Framework deviation: Tests use Swift Testing (`@Test`/`#expect`) not XCTest per plan spec
