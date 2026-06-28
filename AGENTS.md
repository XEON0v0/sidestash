# SideStash — Agent Guide

## Build & Run

```bash
# Build (no Xcode required)
swift build -c release

# Package as .app bundle (generates icon, Info.plist, .icns)
./build_app.sh

# Open the bundled app
open SideStash.app
```

- **Swift 6.2** — uses `swift-tools-version: 5.9`, targets `macOS 14+`
- No xcodeproj — SPM-only. `Package.swift` has a single `.executableTarget`
- Tests exist under `Tests/SideStashTests`; run them with `swift test`.
- No CI. No linting config.

## Architecture

A menu-bar-only app that acts as a temporary file drop zone. Files dragged in from Finder are stashed; files dragged back out are restored to their original location.

| File | Role |
|---|---|
| `SideStashApp.swift` | `@main` — adapts `AppDelegate`, Scene is `Settings { EmptyView() }` |
| `AppDelegate.swift` | Sets up `NSStatusItem` (menu bar icon), starts global drag detector, handles right-click context menu |
| `StashStore.swift` | `@MainActor ObservableObject` — singleton managing files in `~/Library/Application Support/SideStash/Stash/` |
| `StashWindowManager.swift` | Manages the floating `NSPanel` — borderless, non-activating, `.floating` level |
| `Services/DragDetector.swift` | Global mouse event monitor — triggers panel near mouse when Finder drag exceeds 40px threshold within 2s |
| `Views/StashContentView.swift` | Main panel UI — header with custom drag handle, file grid, empty state |
| `Views/FileGridItem.swift` | SwiftUI wrapper for `DraggableFileItem` |
| `Views/DropZoneView.swift` | Root `NSView` of panel — registers `.fileURL` drag types, hands to `StashStore` |
| `DragOut/DraggableFileItem.swift` | `NSViewRepresentable` — renders file icon + name, supports drag-out via `NSDraggingSession` |

## Key Behaviors

### Stashing (drag in)
- `DropZoneNSView.performDragOperation` → `StashStore.stash(url:)`
- Tries `moveItem` first, falls back to `copyItem` + `removeItem`
- Original path saved in `.metadata.json` for later restore
- On name collision, appends counter: `"file.txt"` → `"file 2.txt"`

### Unstashing (drag out)
- `DraggableFileItemView` starts `NSDraggingSession` with `.fileURL` type
- Offers `[.copy, .move, .link]` operations
- `draggingSession(endedAt:)` on successful drop → `StashStore.finalizeDrag(item:)`
- 0.3s delay to let Finder finish, then checks if file still in stash — if so, moves it back to original directory (with collision-safe naming)

### Panel visibility
- Panel hides when close button clicked or when toggled off from status bar
- Drag detection is **paused** while panel is visible; **resumed** when hidden
- Window dragged via `WindowDragHandle` (custom mouse-tracking NSView, not `.move` mask)

### Global drag detection
- Only activates when `com.apple.finder` is the frontmost app
- 40px threshold, 2s timeout, 0.03s polling interval

## Gotchas

- **Chinese strings in UI** — menu items use Chinese labels ("显示/隐藏", "打开暂存文件夹", "退出"); empty state text also in Chinese
- **No dock icon** — Info.plist sets `LSUIElement = true`; app only shows in menu bar
- **No Xcode needed** — build with bare `swift build`; `build_app.sh` generates the `.app` bundle structure manually
- **No dependencies** — zero external packages, pure Foundation + AppKit + SwiftUI
- **Git repo exists** — check `git status` before editing because generated and agent-workflow artifacts may be present locally.
- **`NSPanel` config** — `.borderless | .nonactivatingPanel`, `.floating` level, `canJoinAllSpaces`, does not hide on deactivate. Changing these breaks the floating-drop-zone UX.
- **`StashStore` is `@MainActor`** — all mutations must be on main actor. Both SwiftUI views (via `@EnvironmentObject`) and AppKit callers (from drag delegates) already run on main.
