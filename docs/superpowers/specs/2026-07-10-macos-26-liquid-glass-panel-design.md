# SideStash macOS 26 Liquid Glass Panel Design

## Summary

Refactor the SideStash panel into a native macOS 26 Liquid Glass utility surface.

The approved direction is a single system glass surface with a quiet content hierarchy and one grouped glass control area. SideStash will require macOS 26; there will be no legacy material fallback.

This is a visual and structural UI refactor. File storage, drag-in, drag-out, batch operations, Finder attachment, panel animation, and panel lifecycle behavior remain unchanged.

## Context

The current implementation already creates `NSGlassEffectView` on macOS 26, but the panel does not yet read as a native Liquid Glass surface because it combines several overlapping treatments:

- `StashWindowManager` inserts an AppKit glass view behind the drop zone.
- `StashContentView` creates a second glass surface through `GlassBackgroundView`.
- Opaque adaptive fills, white and black strokes, layer shadows, and a manually simulated material toolbar are painted above those surfaces.
- The AppKit glass and content views are siblings, even though `NSGlassEffectView` only guarantees correct glass placement and z-order for its `contentView`.

Together these layers produce a cloudy, framed appearance instead of one coherent system surface.

## Goals

- Make the panel unmistakably native to macOS 26.
- Use one system-owned glass surface for the panel body.
- Use native interactive glass for the three bulk actions.
- Keep the file content visually quiet and readable over changing desktop backgrounds.
- Preserve all existing drag-and-drop, Finder attachment, alert, and panel lifecycle behavior.
- Preserve the current uncommitted alert-lifecycle changes while implementing the refactor.
- Keep the AppKit and SwiftUI boundary small and explicit.

## Non-Goals

- Changing stash persistence, collision handling, restore behavior, or file-system operations.
- Changing how Finder windows are detected, followed, or matched.
- Changing the panel's borderless, non-activating, floating window behavior.
- Adding preferences, color themes, custom glass tints, or new commands.
- Redesigning the menu bar menu or app icon.
- Updating historical roadmap or implementation-plan documents that describe the old minimum system version.

## Approved Direction

The selected visual direction is **System Single Surface**:

- One regular Liquid Glass panel body.
- No nested content plate.
- No separate glass header.
- No manual panel fill, highlight stroke, subtle border, or content shadow.
- One native grouped glass area for the bottom actions.
- Semantic monochrome controls, with color reserved for the close control.

Two alternatives were rejected:

- **Layered Glass** added an outer shell, inner plate, and floating header. It made the glass effect more obvious but reintroduced visual noise and contrast risk.
- **Clear Glass Tool Rail** used three separate floating controls and a clearer panel. It felt more decorative and less like a focused Finder utility.

## Deployment Target

SideStash will require macOS 26.

The following active product metadata must agree on that requirement:

- `Package.swift`: `.macOS("26.0")`
- `build_app.sh`: `LSMinimumSystemVersion` set to `26.0`
- `README.md`: system requirement changed to macOS 26 or newer
- `BuildAppScriptTests`: verify the packaged minimum system version is `26.0`

All `#available(macOS 26, *)` material fallbacks in the panel surface code will be removed.

The package keeps `swift-tools-version: 5.9`. The string-form platform declaration is intentional because the typed `.v26` constant requires PackageDescription 6.2, while `.macOS("26.0")` expresses the same deployment target with the existing manifest API.

## Panel Surface Architecture

`StashWindowManager` remains the owner of the `NSPanel` and its AppKit content hierarchy.

The new hierarchy is:

```text
NSPanel
└── NSGlassEffectView (.regular, 24 pt corner radius)
    └── contentView: DropZoneNSView
        ├── NSHostingView<AnyView>
        └── PanelEdgePreviewView
```

The root `NSGlassEffectView` becomes `panel.contentView`. `DropZoneNSView` is assigned through `NSGlassEffectView.contentView`, rather than added as an arbitrary sibling of the glass view. The hosting view and reveal-only edge preview remain children of the drop zone so their existing event and z-order behavior is preserved.

A small AppKit surface factory will own creation of the root `NSGlassEffectView`. It will configure:

- `.regular` style
- `24` point corner radius
- the provided drop zone as `contentView`
- a frame and autoresizing mask matching the panel

The existing SwiftUI `GlassBackgroundView` becomes unnecessary and will be removed. The SwiftUI root renders transparent content only.

The following `NSPanel` configuration remains unchanged:

- `.borderless | .nonactivatingPanel`
- `.floating` level
- `.canJoinAllSpaces | .fullScreenAuxiliary`
- `hidesOnDeactivate = false`
- `isMovableByWindowBackground = false`
- clear window background
- system panel shadow enabled

The manual layer border and layer shadow on the current AppKit container will be removed. Depth comes from the system glass and the panel's system shadow.

## SwiftUI Composition

### Root Layout

`StashContentView` keeps its fixed width and placement-driven height, but its root no longer paints a background. It contains only:

- header
- file list or empty state
- bottom bulk actions
- existing alert presentation

There is no inner plate inset. Content is laid out directly inside the system glass surface.

### Header

The header remains `58` points high and keeps:

- the centered `SideStash` title
- the `12` point red close control
- reserved leading and trailing title space
- the transparent AppKit drag handle

The header has no independent material, fill, border, or shadow. The close control remains the only decoratively colored control because red communicates its window-closing role.

### File Rows

File rows remain `39` points high with their current icon, truncated filename, and drag-out implementation.

Rows are content, not glass cards. They keep a subtle semantic hover fill and do not receive `glassEffect`. This preserves scan density and avoids a collection of refracting surfaces inside the main glass panel.

### Empty State

The empty state stays centered and unframed. Its symbol and text use semantic secondary foreground styles so the system can maintain contrast across appearance and wallpaper changes.

### Bottom Bulk Actions

The three bulk actions remain centered `16` points above the bottom edge. Each action keeps a fixed `44` by `38` point hit region and its current SF Symbol, tooltip, accessibility label, enabled state, and command behavior.

On macOS 26, the controls are rendered inside one `GlassEffectContainer` with native glass button styling. Adjacent controls use zero visual spacing so the system can render them as one coherent grouped surface. No custom material fill, white highlight, black outline, or hand-authored shadow is added.

The custom floating hover-title overlay is removed. Native glass hover and press feedback provides the immediate affordance, while `.help` supplies the textual tooltip.

No glass tint is applied. Icons stay monochrome and use semantic foreground styles. The destructive meaning of Trash is communicated by the confirmation alert, not by a permanently red toolbar icon.

Disabled state is passed to the native button style. No custom disabled opacity is applied.

## State And Data Flow

The refactor adds no new application state.

The existing flow remains:

```text
DropZoneNSView -> StashStore -> published items -> StashContentView
DraggableFileItemView -> StashStore.finalizeDrag
Bulk action button -> StashStore batch operation -> existing result alert
Alert presentation state -> StashWindowManager -> pause/resume Finder following
```

The current uncommitted `onAlertPresentationChanged` callback and `isContentModalPresented` lifecycle behavior must be retained exactly while the view structure changes.

## Error Handling

Liquid Glass creation has no fallback path because the executable requires macOS 26.

All user-facing operational errors continue through the current alert paths:

- confirmation before moving every item to Trash
- failure to resolve the current Finder folder
- partial batch-operation results
- absence of restorable items

The visual refactor must not intercept, replace, or suppress those alerts.

## Accessibility And Adaptation

- Use system semantic foreground styles rather than fixed light or dark text colors.
- Keep existing accessibility labels on the close and bulk-action controls.
- Keep `.help` tooltips for every icon-only bulk action.
- Preserve fixed hit regions so interactive glass does not resize or shift the toolbar.
- Let `NSGlassEffectView` and native glass button styles adapt to Light Mode, Dark Mode, increased contrast, and reduced transparency.
- Preserve the existing panel and row motion policies; do not add decorative glass morphing or continuous animation.

## Style Policy Cleanup

`SideStashSidebarStyle` and `SideStashSidebarChromePolicy` should retain geometry, symbol names, and content metrics that remain meaningful.

The following legacy concepts should be removed when no longer referenced:

- pane and header appearance structs used only for overlay colors
- inner sidebar plate inset and corner radius
- simulated panel fill alpha
- panel and inner-plate highlight and border alpha values
- manual content shadow values
- bottom toolbar overlay, border, highlight, and shadow values
- custom hover-title offset and hover-title state

The result should describe layout and behavior, not encode a hand-built approximation of system glass.

## Testing Strategy

Implementation follows test-first development.

### Automated Tests

1. Add a focused AppKit surface test before adding the surface factory. It verifies that the produced root is `NSGlassEffectView`, uses `.regular`, has a `24` point corner radius, and owns the supplied content through `contentView`.
2. Update style-policy tests before changing production constants. The new contract covers the approved panel radius, header geometry, row density, bottom action hit regions, and SF Symbol availability.
3. Replace tests for custom fill, stroke, shadow, dark-mode overlay, and hover-title metrics because those concepts no longer exist.
4. Extend `BuildAppScriptTests` before changing the script so it requires `LSMinimumSystemVersion` to be `26.0`.
5. Preserve and run the existing panel lifecycle, placement, Finder tracking, interaction motion, store, and packaging tests.

### Build Verification

Run fresh commands after implementation:

```bash
swift test
swift build -c release
./build_app.sh
```

The packaged `SideStash.app/Contents/Info.plist` must report `26.0` for `LSMinimumSystemVersion`.

### Runtime And Visual Verification

Launch the packaged `.app`, not the raw SwiftPM executable. Verify:

- empty state in Light Mode and Dark Mode
- populated rows using controlled temporary files
- row hover and file drag-out
- file drag-in through the full panel surface
- native hover and press feedback for every bulk action
- Trash confirmation and result alerts
- Finder-attached and free-floating placement
- panel reveal, close, and follow behavior

Capture Light Mode and Dark Mode screenshots against visually varied desktop content. Inspect the screenshots for:

- one coherent refracting panel surface
- no cloudy inner plate or double blur
- no hard rectangular hosting-view background
- legible text and icons
- clean `24` point corner clipping
- stable bottom toolbar dimensions
- no overlapping tooltip, alert, header, row, or toolbar content

## Acceptance Criteria

- SideStash builds and packages with macOS 26 as its minimum system version.
- The panel has exactly one system Liquid Glass body surface.
- App content is hosted through `NSGlassEffectView.contentView`.
- No SwiftUI or AppKit fallback material remains in the panel body.
- Header and file content have no independent glass card or opaque plate.
- Bottom bulk actions use native grouped glass controls without simulated chrome.
- Existing drag, stash, restore, batch-action, Finder attachment, alert, and panel lifecycle behavior remains intact.
- Existing user work in the dirty worktree is preserved.
- Automated tests and release build pass.
- Runtime screenshots pass the visual checks in both Light Mode and Dark Mode.
