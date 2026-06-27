## F2 Code Quality Review — Learnings

### Build
- `swift build` — PASS (0.09s)
- `swift build --build-tests` — PASS (0.07s)
- `swift test` — not run (XCTest framework unavailable on CLT-only macOS)

### Files Reviewed (10 total)
All 10 Swift files in Sources/FileStash/ reviewed line-by-line.

### Issues Found

#### 1. `print()` instead of Logger (StashStore.swift)
- **Line 208**: `print("Failed to stash \(sourceURL): \(error)")` — should be `logger.error(...)`
- **Line 261**: `print("Failed to restore \(item.url) to \(restoreURL)")` — should be `logger.error(...)`
- Line 188 is the acceptable self-stash rejection guard print

#### 2. Force unwrap (AppDelegate.swift:42)
- `let event = NSApp.currentEvent!` — safe AppKit pattern from button action selector. Acceptable.

#### 3. Empty catch blocks
- All 13 `catch` blocks in StashStore.swift contain either `logger.error(...)` logging, variable assignment, or `return`. No truly empty catches.

### Clean Checks
- ✅ Zero TODO/FIXME/HACK/XXX markers
- ✅ No commented-out code blocks
- ✅ No unused imports
- ✅ Only 1 protocol: `FileSystemProvider`
- ✅ No LRU cache or memory pressure handling — simple `[String: NSImage]` Dictionary
- ✅ No over-abstraction or generic names
- ✅ FileGridItem thin wrapper justified as SwiftUI integration layer
- ✅ Known acceptable: `StashStore.shared`, `StashWindowManager.shared`
