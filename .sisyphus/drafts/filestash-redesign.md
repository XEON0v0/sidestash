# Draft: FileStash UI Redesign

## Requirements (confirmed)

### Visual Style
- macOS 26 Tahoe Liquid Glass design language
- Panel uses translucent glass material, refracts/reflects surroundings
- Follows system dark/light mode automatically
- Single column list layout (like Finder sidebar)
- List items: icon + filename only (精简)
- Panel width: 320px
- Header: keep "FileStash" title + close button + drag handle (redesigned in Liquid Glass style)
- Empty state: keep icon + text, beautified with Liquid Glass aesthetic

### Panel Positioning
- **Finder window present**: Panel attaches to Finder window's right side, tracking position/resize
- **Desktop (no Finder window)**: Panel appears near mouse cursor (current behavior)
- Window follows Finder's move/resize in real-time

### Activation Model
- **Dual trigger**: Drag detection + menu bar click/keyboard toggle
- Drag detection: 2 second timeout + ~30-50px distance threshold (currently 12px + 1s)

### Animation System
| Action | Animation |
|--------|-----------|
| Panel expand | Drawer slide-in from Finder right edge |
| Panel close | Drawer slide-out to Finder right edge |
| File drop-in | File item fade-in with bounce/spring |
| File drag-out (success) | Scale down + fade out |
| File drag-out (fail) | Bounce back to original position |

### Interaction Changes
- Right-click context menu on file items: "Restore to original location" + "Delete"
- Drag-out failure: Keep current behavior (restore to original location after timeout)
- Drag sensitivity: Less sensitive (2s, 30-50px threshold)

### Drag Detection Changes
- Timeout: 1s → 2s
- Distance threshold: 12px → 30-50px

## Technical Decisions
- Finder window tracking: Use Accessibility API (AXUIElement) to observe Finder window position/size
- Liquid Glass material: NSVisualEffectView with appropriate macOS 26 material/blending mode
- Drawer animation: NSAnimationContext + spring animation for panel expand/collapse
- File item animations: SwiftUI .animation() modifiers with spring response
- Right-click menu: NSMenu integration on DraggableFileItemView
- Dark mode: Follow system appearance (NSApp.effectiveAppearance)

## Scope Boundaries
- INCLUDE: Visual redesign, panel positioning, animation system, right-click menu, drag sensitivity, layout change
- EXCLUDE: Multi-select drag, file search, file preview, global shortcuts, file tags/categories, automated testing infrastructure

## Test Strategy Decision
- Infrastructure exists: NO
- Automated tests: NO
- Agent-Executed QA: ALWAYS (manual build verification + visual verification)

## Open Questions
- None remaining - all decisions confirmed