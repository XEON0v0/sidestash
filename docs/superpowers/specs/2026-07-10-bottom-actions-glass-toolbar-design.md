# SideStash Bottom Actions Glass Toolbar Design

## Summary

Refine the three bottom bulk-action buttons into one floating pill-shaped glass toolbar. The toolbar must communicate enabled, disabled, hovered, and pressed states, and every icon-only command must show a reliable localized purpose tooltip. Disabled commands must still explain why they are unavailable.

The selected visual direction is a quiet unified capsule: one glass surface surrounds all three actions, while a light lens appears only behind the currently hovered or pressed button.

## Scope

This change is limited to the bottom bulk-action toolbar and the panel mouse-movement configuration required to support its hover behavior.

It does not change:

- the `.borderless | .nonactivatingPanel` window style
- panel placement, reveal, Finder following, or close behavior
- stash, move, restore, collision, or metadata behavior
- the three existing commands or their confirmation and result alerts
- the current macOS 14 deployment target

## Current Problems

The current implementation cannot present complete control state reliably:

- Buttons use `.buttonStyle(.plain)`, so they have no standard hover or press treatment.
- Disabled behavior is implemented as an action guard instead of `.disabled`, so SwiftUI and accessibility still treat the controls as enabled.
- All three actions share the same empty-stash check, even though Restore also becomes unavailable when no item has an original location.
- The custom hover title extends outside a toolbar view whose layout height is only `38` points.
- Hover behavior depends on SwiftUI tracking inside a non-activating panel, but the panel does not explicitly accept mouse-moved events.

## Approved Visual Direction

Use one centered glass capsule with three equal icon hit regions.

- Toolbar height: `40` points.
- Button hit region: `44` points wide and the full toolbar height.
- Outer shape: one capsule; no internal divider lines.
- Icons: existing monochrome SF Symbols with semantic foreground colors.
- Default enabled state: stable primary icon contrast with no individual fill.
- Hover state: a restrained circular/capsule lens behind the button and `1.04` content scale.
- Pressed state: `0.94` content scale with a subtle inset response.
- Disabled state: icon opacity `0.28`; no hover lens or press response.
- Tooltip: a compact glass label above the toolbar, outside the capsule's clipping and layout bounds.

The Trash action remains monochrome. Its destructive meaning continues to be communicated by the confirmation alert rather than a permanently red icon.

## Glass Rendering

On macOS 26 and newer, render the outer capsule with one native SwiftUI glass effect:

```swift
.glassEffect(.regular.interactive(), in: Capsule())
```

The effect belongs to the toolbar container, not to each button. This preserves the approved single-surface appearance.

On macOS 14 through 25, retain a visually equivalent capsule using `.regularMaterial`, a restrained adaptive border, and the existing low-opacity shadow. The fallback is isolated behind availability-aware toolbar composition; action and state logic are shared across both paths.

Do not add glass tint. Do not place three independent glass buttons inside another glass capsule.

## Component Design

### Bottom Action Toolbar

Create `Views/BottomActionToolbar.swift` and move the toolbar composition out of `StashContentView`. The component owns:

- the single capsule surface
- fixed toolbar geometry
- the three equal action regions
- currently hovered action
- delayed tooltip presentation and cancellation
- the tooltip overlay positioned above the capsule

`StashContentView` continues to own alert state and command closures.

### Bulk Action Control

Each action region wraps a real SwiftUI `Button` and receives an availability value. The wrapper, rather than the disabled button, owns hover tracking so disabled commands can still show help.

The button receives `.disabled(!availability.isEnabled)` and keeps its localized accessibility label and `.help` string. A small custom button style reads `configuration.isPressed` and `EnvironmentValues.isEnabled` to render the approved lens, scale, and opacity without changing the fixed hit region.

### Availability

Represent availability as enabled or disabled with a localized reason. It is derived from the current `store.items` value:

- Trash All is enabled when the stash is not empty.
- Move All to Current Folder is enabled when the stash is not empty.
- Restore All is enabled when at least one item has a non-nil original URL.
- When the stash is empty, all actions are disabled with an empty-stash reason.
- When items exist but none can be restored, only Restore is disabled with a no-original-location reason.

Finder destination resolution remains an action-time operation. A missing current Finder folder continues to show the existing alert rather than causing hover-time Finder queries.

## Tooltip Behavior

Hovering any action schedules its tooltip after a `350 ms` delay. This avoids flicker while crossing the toolbar.

- Enabled action: show the localized purpose.
- Disabled action: show the localized purpose plus a concise unavailable reason.
- Moving directly between buttons updates the visible tooltip without another long delay.
- Leaving the toolbar cancels pending presentation and dismisses the tooltip.
- Pressing a button dismisses the tooltip before running the action.

The custom tooltip is the visible in-panel affordance. `.help` remains as a system fallback and accessibility-friendly description.

The panel sets `acceptsMouseMovedEvents = true`. No other `NSPanel` style or activation behavior changes.

## State Flow

```text
StashStore.items
    -> availability for each SideStashBulkAction
    -> Button.disabled and visual emphasis

pointer enters action wrapper
    -> hovered action
    -> delayed tooltip title and optional disabled reason

button press
    -> pressed visual state
    -> existing StashContentView action closure
    -> existing StashStore batch operation and alerts
```

No new persistent state is introduced.

## Localization And Accessibility

Keep the existing localized purpose keys:

- `bulk.trash.tooltip`
- `bulk.move_current.tooltip`
- `bulk.restore.tooltip`

Add localized disabled reasons for an empty stash and for the absence of restorable files. Provide English and Simplified Chinese values.

Each button keeps:

- its localized accessibility label
- true disabled semantics
- a fixed `44 x 40` point hit region
- the system `.help` description

The tooltip must not intercept pointer events or overlap the toolbar, file rows, or panel edge.

## Testing

Implementation follows test-first development.

Automated tests cover:

- all three actions are disabled for an empty stash
- Trash and Move are enabled when items exist
- Restore is disabled when no item has an original URL
- Restore is enabled when at least one item has an original URL
- every action has a non-empty purpose localization key
- every disabled state resolves a non-empty reason key
- approved toolbar and hit-region geometry remains stable
- the panel interaction policy enables mouse-moved events without changing its non-activating style

SwiftUI hover animation and glass rendering require runtime visual verification. Package and launch the `.app`, then check:

- default, hover, press, and disabled states
- tooltips for enabled and disabled actions
- direct pointer movement between all three actions
- Light Mode and Dark Mode
- empty, non-restorable, and restorable item sets
- no layout shift, clipping, or overlap

Run fresh verification commands:

```bash
swift test
swift build -c release
./build_app.sh
```

## Acceptance Criteria

- The bottom controls render as one floating pill-shaped glass surface.
- The toolbar keeps three stable, equal hit regions without layout movement.
- Enabled, hovered, pressed, and disabled states are visually distinct.
- SwiftUI and accessibility receive true disabled state.
- Restore availability reflects whether any item can actually be restored.
- Every action shows its purpose; disabled actions also show why they are unavailable.
- Tooltips remain inside the panel content area and are not clipped by the toolbar.
- Existing batch actions, alerts, panel behavior, and macOS 14 compatibility remain intact.
