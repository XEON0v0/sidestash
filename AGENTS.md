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

- **Swift 6.2** — uses `swift-tools-version: 5.9`, targets `macOS 26+` (declared as `.macOS("26.0")`)
- `build_app.sh` accepts optional `SIDESTASH_BUILD_DIR`, `SIDESTASH_APP_DIR` and `SIDESTASH_SWIFTPM_CACHE` to keep build output and the bundle outside the workspace
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
| `Views/StashPanelSurfaceFactory.swift` | Builds the panel's single `NSGlassEffectView` (Liquid Glass body) and re-tints it on appearance changes |
| `Views/SideStashGlassPalette.swift` | Light/dark color tokens; AppKit layers resolve them against `effectiveAppearance` |
| `Views/StashContentView.swift` | Main panel UI — header with custom drag handle, file grid, empty state |
| `Views/MoreActionsPill.swift` | Header capsule (top right): `…` menu of more actions, leading segment repeats the last one used; hosts the system share picker |
| `Views/SideStashMoreActions.swift` | `SideStashMoreAction` (drag all out, share, export archive, format conversion placeholder) and `MoreActionsMemory` (last used, in `UserDefaults`) |
| `DragOut/MultiFileDragSource.swift` | Drags every stashed file out in one `.copy` session; files stay in the stash |
| `Services/StashArchiveExporter.swift` | Zips stashed files (via `/usr/bin/ditto`, no `__MACOSX` sidecars) into the current Finder folder |
| `Views/BottomActionToolbar.swift` | Bulk-action capsule — native `glassEffect`, hover lens, delayed tooltips with disabled reasons |
| `Views/FileGridItem.swift` | One file on its own glass plate — `DraggableFileItem` on top, plate with a lit bevel behind (light-mode wash only on the plateau); registers its icon as a light |
| `Lighting/GlassLightingScene.swift` | Shared light environment: icon light positions, pointer-following key light, panel bounds; pushes changes straight to the bevels (no SwiftUI updates) |
| `Lighting/GlassBevel.swift` | Slab geometry: convex slope profile (plateau + curved edge), normals, Fresnel, refraction offset, rounded-rect outline distance |
| `Lighting/GlassLightingEngine.swift` | Bevel lighting: packs one surface's lights into shader uniforms, plus the Swift reference of the shader (`bevelLight`/`bevelColor`) |
| `Lighting/GlassBevelRenderer.swift` | MSL shader compiled at run time; draws bevels into IOSurface-backed textures, batched per run loop pass |
| `Lighting/GlassRim.swift` | The lit bevel on the panel, the action pill and every file plate — shows the rendered IOSurface as layer contents, redrawn only when its lighting changes |
| `Lighting/IconLightSampler.swift` | Turns a file icon into a light (dominant hue, strength by colorfulness, reds kept paler) |
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
- **Liquid Glass** — the panel body is exactly one `NSGlassEffectView`; content goes through its `contentView`. Don't add materials, fills, strokes or shadows on top — they read as a cloudy second layer.
- **Glass edge lighting** — every glass surface (panel, action pill, file plates) is a curved-edge slab: the plateau stays native glass, and only the slope band (`GlassLightingStyle.bevel(for:)`) is lit, through `GlassRim` + `GlassLightingScene`; don't hand-draw edge gradients. Tune it in `GlassLightingStyle` / `IconLightStyle`. Rims must sit in the `GlassLightingSpace` coordinate space, and the pointer reaches the scene through `DropZoneNSView.onPointerMoved`.
- **Bevel shader** — the MSL in `GlassBevelRenderer.shaderSource` mirrors `GlassLightingEngine.bevelLight(at:lighting:)` line by line; change both together and run `GlassBevelRendererTests` (GPU vs Swift reference). It is compiled at run time on purpose: no `.metal` files, so plain `swift build` needs no Metal toolchain. Bevels draw into IOSurfaces rather than a `CAMetalLayer`, whose `nextDrawable()` can block the main thread while the panel is hidden.
- **File row plates** — the AppKit row content stays above the plate; keep rows out of `GlassEffectContainer`, which re-layers glass (the pill's rim is attached outside its container for the same reason).
- **Light/dark** — never hard-code white/black `CGColor`s. Use `SideStashGlassPalette` tokens and re-apply layer colors in `viewDidChangeEffectiveAppearance()`, otherwise they go stale when the system appearance switches.
- **`StashStore` is `@MainActor`** — all mutations must be on main actor. Both SwiftUI views (via `@EnvironmentObject`) and AppKit callers (from drag delegates) already run on main.
