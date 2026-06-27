# FileStash UI Redesign — macOS 26 Liquid Glass + Finder Attachment + Animation System

## TL;DR

> **Quick Summary**: Redesign FileStash's visual layer to match macOS 26 Tahoe's Liquid Glass aesthetic, implement Finder-window-attached panel positioning (with Accessibility permission), and add a complete animation feedback system (drawer slide, spring insert, scale-fade drag-out).
> 
> **Deliverables**:
> - Liquid Glass visual design (dual-path: macOS 26+ glass / macOS 14-25 blur fallback)
> - Finder-window-attached panel positioning (graceful degradation for Desktop/no-permission)
> - Single-column file list layout (replacing 2-column grid)
> - Animation system: panel drawer slide, file spring insert, drag-out scale-fade
> - Right-click context menu (Restore to Original + Move to Trash)
> - Updated drag detection thresholds (40px distance, 2s timeout)
> - Localization updates for all new strings
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Task 1 → Task 2 → Task 5 → Task 8 → Task 10 → Task 12 → F1-F4

---

## Context

### Original Request
User wants to optimize FileStash's frontend style (matching macOS 26 Finder's Liquid Glass design) and then optimize its interaction logic (animations, positioning, context menus).

### Interview Summary
**Key Discussions**:
- Visual direction: macOS 26 Tahoe Liquid Glass style — translucent, refractive, follows system dark/light mode
- Panel positioning: Attach to Finder window's right side when Finder has windows; fall back to mouse-position on Desktop
- Activation: Dual trigger — drag detection + menu bar click
- Drag detection sensitivity: 2s timeout + ~40px distance threshold (currently 12px + 1s)
- File layout: Single-column list (replacing 2-column grid), 320px wide
- File item info: Icon + filename only
- Animations: Drawer slide-in/out for panel; spring/bounce for file insert; scale+fade for drag-out
- Right-click menu: "Restore to Original Location" + "Move to Trash"
- macOS version: Keep macOS 14+ support with Liquid Glass degradation
- Accessibility permission: Required for Finder-attach; fallback to mouse-position without it
- Multi-Finder-window: Follow frontmost window
- No automated tests — agent-executed QA only
- Exclusions: multi-select, search, preview, global shortcuts, tags

**Research Findings**:
- macOS 26 introduces `NSGlassEffectView` (AppKit) and `.glassEffect()` (SwiftUI) for Liquid Glass
- `NSGlassEffectView.contentView` is the only guaranteed-rendering subview — arbitrary subviews may not render correctly
- Finder window tracking requires Accessibility API (`AXIsProcessTrusted`) — a system-level permission prompt
- `kAXWindowMovedNotification` only fires AFTER window move completes (not during drag)
- `CGWindowListCopyWindowInfo` can poll window positions during drag but is CPU-intensive
- `NSDrawer` is deprecated; `addChildWindow` only works within same process
- Current code has singleton coupling: `DragDetector.shared`, `StashStore.shared`, `StashWindowManager.shared`

### Metis Review
**Identified Gaps** (addressed):
- macOS 14-25 compatibility: Added dual-path GlassBackgroundView abstraction
- Accessibility permission: Required for Finder-attach, graceful mouse-position fallback
- NSGlassEffectView view hierarchy: Restructured so contentView is the NSHostingView, drag-drop as overlay
- Context menu "Delete" vs "Move to Trash": Using standard macOS Trash behavior
- Multiple Finder windows: Follow frontmost window
- Drag-over visual feedback on DropZone: Added highlight state
- Animation drag conflict: Disable drag-acceptance during panel animation

---

## Work Objectives

### Core Objective
Transform FileStash from a basic utility toolbar app into a polished macOS 26-native experience that visually and behaviorally integrates with Finder, while maintaining full backward compatibility with macOS 14.

### Concrete Deliverables
- `GlassBackgroundView` — abstraction over `NSGlassEffectView` (macOS 26+) and `NSVisualEffectView` (macOS 14-25)
- `FinderWindowTracker` — Accessibility-based Finder window position observer with graceful no-permission fallback
- `StashContentView` rewrite — single-column list layout, Liquid Glass aesthetic, spring animations
- `DraggableFileItemView` rewrite — list-style item, context menu, drag-out animation
- `StashWindowManager` rewrite — drawer slide animation, Finder-attached positioning, 320px width
- `DragDetector` update — 40px threshold, 2s timeout
- `StashStore` additions — `delete(item:)` (trash) and `restoreToOriginal(item:)` methods
- Updated `Localizable.strings` for both `en.lproj` and `zh-Hans.lproj`
- Updated `DropZoneNSView` — visual drag-over feedback state

### Definition of Done
- [ ] `swift build -c release` exits 0
- [ ] `./build_app.sh` exits 0 and `FileStash.app` is valid
- [ ] On macOS 14-25: Panel shows `NSVisualEffectView` blur background (no crash)
- [ ] On macOS 26+: Panel shows Liquid Glass background (no crash)
- [ ] Dragging file from Finder into panel stashes it (existing behavior preserved)
- [ ] Dragging file out of panel restores it (existing behavior preserved)
- [ ] Clicking menu bar icon toggles panel visibility
- [ ] Panel is 320px wide (not 300px)
- [ ] File items display in single-column list
- [ ] Right-click on file item shows context menu with "Restore to Original Location" and "Move to Trash"
- [ ] "Move to Trash" moves file to macOS Trash
- [ ] Panel open has slide-in animation; close has slide-out animation
- [ ] File items have spring animation on insertion
- [ ] Drag detection requires 40px movement and 2s hold
- [ ] Localization strings updated in both English and Chinese

### Must Have
- macOS 14+ backward compatibility (Liquid Glass degrades to blur)
- Finder-window-attached positioning when Accessibility permission granted
- Mouse-position fallback when no Accessibility permission or on Desktop
- Drawer slide-in/out animations for panel
- Spring animation for file item insertion
- Scale+fade animation for drag-out; bounce-back on failure
- Single-column list layout at 320px width
- Right-click context menu (Restore + Move to Trash)
- Drag-over visual feedback on DropZone
- All UI strings localized in English and Chinese

### Must NOT Have (Guardrails)
- ❌ Multi-select file drag
- ❌ File search functionality
- ❌ File preview/QuickLook
- ❌ Global keyboard shortcuts
- ❌ File tags or categories
- ❌ `NSDrawer` usage (deprecated)
- ❌ `addChildWindow` with Finder windows (cross-process, won't work)
- ❌ Requiring Accessibility permission for core functionality (drag-in/out must work without it)
- ❌ Changing `StashStore` file operations, metadata format, or stash directory location
- ❌ Changing `DropZoneNSView` drag-in pasteboard type or mechanism
- ❌ Changing `DraggableFileItemView` drag-out `NSDraggingSession` mechanism
- ❌ Polling `CGWindowListCopyWindowInfo` continuously (CPU waste)
- ❌ Permanent delete in context menu (must use Trash)
- ❌ Excessive AI slop: over-commenting, unnecessary abstractions, generic naming (data/result/item)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (no test target content, no CI)
- **Automated tests**: None (per user decision)
- **Framework**: N/A
- **Agent-Executed QA**: ALWAYS (mandatory for all tasks)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **macOS App**: Use Bash — build, run, verify file existence, check `swift build` output
- **UI Verification**: Use Playwright skill — launch app, verify DOM state, screenshot
- **Code Verification**: Use Bash — `swift build`, `file` checks, `plutil` for Info.plist

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation — independent scaffolding + data layer):
├── Task 1: GlassBackgroundView abstraction [quick]
├── Task 2: StashStore — add delete/restore methods [quick]
├── Task 3: DragDetector — update thresholds [quick]
└── Task 4: Localization keys for new strings [quick]

Wave 2 (Core views — depends on Wave 1):
├── Task 5: StashContentView rewrite — Liquid Glass + single-column list [deep]
├── Task 6: DraggableFileItemView rewrite — list item + context menu + drag-out animation [unspecified-high]
├── Task 7: DropZoneNSView — drag-over visual feedback [quick]
└── Task 8: FinderWindowTracker — Accessibility-based position observer [deep]

Wave 3 (Window management + integration — depends on Wave 2):
├── Task 9: StashWindowManager rewrite — drawer animation + Finder-attached positioning [deep]
├── Task 10: Panel animation system — slide-in/out springs [unspecified-high]
└── Task 11: AppDelegate — wire new components + menu updates [quick]

Wave 4 (Polish + verification):
├── Task 12: Integration testing + edge cases [unspecified-high]
└── Task 13: Final build verification + localization check [quick]

Wave FINAL (After ALL tasks):
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA (unspecified-high)
└── F4: Scope fidelity check (deep)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 5 |
| 2 | — | 6, 9 |
| 3 | — | 9 |
| 4 | — | 5, 6, 9 |
| 5 | 1, 4 | 9 |
| 6 | 2, 4 | 9, 12 |
| 7 | — | 9, 12 |
| 8 | — | 9 |
| 9 | 2, 3, 4, 5, 6, 7, 8 | 11, 12 |
| 10 | 5 | 9 |
| 11 | 9 | 12 |
| 12 | 6, 7, 9, 11 | F1-F4 |
| 13 | 12 | F1-F4 |

### Agent Dispatch Summary

- **Wave 1**: 4 tasks — T1-T4 → `quick`
- **Wave 2**: 4 tasks — T5 → `deep`, T6 → `unspecified-high`, T7 → `quick`, T8 → `deep`
- **Wave 3**: 3 tasks — T9 → `deep`, T10 → `unspecified-high`, T11 → `quick`
- **Wave 4**: 2 tasks — T12 → `unspecified-high`, T13 → `quick`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. GlassBackgroundView Abstraction

  **What to do**:
  - Create `Sources/FileStash/Views/GlassBackgroundView.swift`
  - Implement a SwiftUI `NSViewRepresentable` that wraps either `NSGlassEffectView` (macOS 26+) or `NSVisualEffectView` (macOS 14-25)
  - Use `#available(macOS 26, *)` check to select the correct implementation at runtime
  - For macOS 26+: Configure `NSGlassEffectView` with appropriate `cornerRadius` (16pt) and set `contentView` to the hosting view
  - For macOS 14-25: Use existing `NSVisualEffectView` with `.hudWindow` material and `.withinWindow` blending mode, `.active` state
  - Expose a `cornerRadius` parameter (default 16) and ensure both paths produce visually consistent rounded corners
  - Remove the existing `VisualEffectBlur` struct from `StashContentView.swift`

  **Must NOT do**:
  - Do NOT use `NSGlassEffectView` without `#available(macOS 26, *)` guard
  - Do NOT use `NSDrawer` (deprecated)
  - Do NOT change `StashStore`, `DragDetector`, or `AppDelegate`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file creation, well-defined AppKit bridge pattern, existing code to reference
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
  - **Blocks**: Task 5
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/FileStash/Views/StashContentView.swift:86-96` — `VisualEffectBlur` struct (this is what we're replacing)
  - `Sources/FileStash/Views/StashContentView.swift:87-95` — Current `NSVisualEffectView` configuration: `.hudWindow` material, `.withinWindow` blending, `.active` state

  **API/Type References**:
  - macOS 26 `NSGlassEffectView` API: `contentView`, `cornerRadius`, `tintColor`, `style`
  - macOS 14 `NSVisualEffectView` API: `material`, `blendingMode`, `state`

  **WHY Each Reference Matters**:
  - `VisualEffectBlur` is the struct being replaced; new code must match its integration point
  - Current NSVisualEffectView config must be replicated in the fallback path

  **Acceptance Criteria**:
  - [ ] `GlassBackgroundView.swift` exists in `Sources/FileStash/Views/`
  - [ ] `swift build -c release` exits 0
  - [ ] On macOS 14-25: `NSVisualEffectView` is used with `.hudWindow` material
  - [ ] On macOS 26+: `NSGlassEffectView` is used with 16pt corner radius
  - [ ] `VisualEffectBlur` struct removed from `StashContentView.swift`

  **QA Scenarios**:

  ```
  Scenario: Build succeeds with GlassBackgroundView
    Tool: Bash
    Preconditions: Project is clean
    Steps:
      1. Run `swift build -c release` in project root
      2. Check exit code is 0
    Expected Result: Build succeeds with no errors
    Failure Indicators: Build errors referencing GlassBackgroundView or missing NSGlassEffectView
    Evidence: .sisyphus/evidence/task-1-build-success.txt

  Scenario: GlassBackgroundView falls back on macOS 14
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Grep `GlassBackgroundView.swift` for `#available(macOS 26`
      2. Grep for `NSVisualEffectView` usage in fallback path
    Expected Result: Both `#available` check and `NSVisualEffectView` fallback are present
    Failure Indicators: Missing `#available` guard or no NSVisualEffectView fallback
    Evidence: .sisyphus/evidence/task-1-fallback-check.txt
  ```

  **Commit**: YES
  - Message: `feat(ui): add GlassBackgroundView with macOS 26 Liquid Glass fallback`
  - Files: `Sources/FileStash/Views/GlassBackgroundView.swift`, `Sources/FileStash/Views/StashContentView.swift`
  - Pre-commit: `swift build -c release`

- [ ] 2. StashStore — Add Delete and Restore Methods

  **What to do**:
  - Add `delete(item:)` method to `StashStore` that moves the stash file to macOS Trash using `FileManager.trashItem(at:)`
  - Add `restoreToOriginal(item:)` method to `StashStore` that moves the file back to its `originalURL` directory with collision-safe naming (reuse `uniqueURL(at:for:)` helper), then removes the metadata entry and calls `refreshItems()`
  - Add `FileSystemProvider.trashItem(at:)` protocol method with `FileManager` extension implementation
  - Both methods must be `@MainActor` and call `refreshItems()` after operation
  - Handle errors: log via `Logger`, don't crash on failure
  - `restoreToOriginal` should create parent directory if it doesn't exist (same as `finalizeDrag` pattern)

  **Must NOT do**:
  - Do NOT permanently delete files — always use Trash
  - Do NOT change existing `stash(url:)`, `finalizeDrag(item:)`, `refreshItems()`, or `loadMetadata()`/`saveMetadata()` signatures
  - Do NOT change the stash directory location or metadata format

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two small methods following existing patterns in StashStore
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4)
  - **Blocks**: Task 6, Task 9
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/FileStash/StashStore.swift:222-268` — `finalizeDrag(item:)` method: pattern for file operations + metadata cleanup + refreshItems (follow this pattern exactly)
  - `Sources/FileStash/StashStore.swift:271-287` — `uniqueURL(at:for:)` method: collision-safe naming (reuse this)
  - `Sources/FileStash/StashStore.swift:245-256` — Parent directory creation pattern (reuse this)

  **API/Type References**:
  - `Sources/FileStash/StashItem.swift:1-15` — `StashItem` struct with `url`, `name`, `originalURL` properties
  - `Sources/FileStash/Services/FileSystemProvider.swift:1-22` — `FileSystemProvider` protocol (add trashItem here)

  **WHY Each Reference Matters**:
  - `finalizeDrag` is the closest existing pattern for file move + metadata cleanup + refresh
  - `uniqueURL(at:for:)` is the collision-safe naming helper that both new methods need
  - `FileSystemProvider` must be extended with `trashItem` to maintain testability

  **Acceptance Criteria**:
  - [ ] `StashStore` has `delete(item:)` method that calls `trashItem`
  - [ ] `StashStore` has `restoreToOriginal(item:)` method that restores to `originalURL`
  - [ ] `FileSystemProvider` protocol has `trashItem(at:) throws -> URL` method
  - [ ] `FileManager` extension implements `trashItem`
  - [ ] Both methods call `refreshItems()` on success
  - [ ] `swift build -c release` exits 0

  **QA Scenarios**:

  ```
  Scenario: Delete method uses Trash
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Grep `StashStore.swift` for `func delete`
      2. Verify it calls `trashItem` (not `removeItem`)
    Expected Result: `delete` method contains `trashItem` call
    Failure Indicators: Method uses `removeItem` or permanent delete
    Evidence: .sisyphus/evidence/task-2-delete-uses-trash.txt

  Scenario: Restore creates parent directory
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Grep `StashStore.swift` for `func restoreToOriginal`
      2. Verify it contains `createDirectory` for parent dir
    Expected Result: `restoreToOriginal` handles missing parent directories
    Failure Indicators: No parent directory creation, would crash on missing dirs
    Evidence: .sisyphus/evidence/task-2-restore-mkdir.txt
  ```

  **Commit**: YES
  - Message: `feat(data): add delete and restore methods to StashStore`
  - Files: `Sources/FileStash/StashStore.swift`, `Sources/FileStash/Services/FileSystemProvider.swift`
  - Pre-commit: `swift build -c release`

- [ ] 3. Update DragDetector Thresholds

  **What to do**:
  - In `DragDetector.swift`, change `dragThreshold` from `12.0` to `40.0`
  - Change `maxDetectionInterval` from `1.0` to `2.0`
  - These are simple constant changes in the `private let` declarations at the top of `DragDetector`

  **Must NOT do**:
  - Do NOT change the polling interval (`0.03`)
  - Do NOT change the Finder bundle identifier check (`com.apple.finder`)
  - Do NOT change the monitoring start/stop lifecycle

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Two constant value changes
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4)
  - **Blocks**: Task 9
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/FileStash/Services/DragDetector.swift:17-19` — The three private constants: `dragThreshold`, `maxDetectionInterval`, `trackingInterval` (change lines 17-18 only)

  **WHY Each Reference Matters**:
  - These are the exact lines to change; line 19 (`trackingInterval = 0.03`) must NOT be changed

  **Acceptance Criteria**:
  - [ ] `dragThreshold` is `40.0` (was `12.0`)
  - [ ] `maxDetectionInterval` is `2.0` (was `1.0`)
  - [ ] `trackingInterval` remains `0.03`
  - [ ] `swift build -c release` exits 0

  **QA Scenarios**:

  ```
  Scenario: Threshold values updated correctly
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Grep `DragDetector.swift` for `dragThreshold` and verify value is `40.0`
      2. Grep for `maxDetectionInterval` and verify value is `2.0`
      3. Grep for `trackingInterval` and verify value is still `0.03`
    Expected Result: dragThreshold=40.0, maxDetectionInterval=2.0, trackingInterval=0.03
    Failure Indicators: Wrong values, or trackingInterval changed
    Evidence: .sisyphus/evidence/task-3-thresholds.txt
  ```

  **Commit**: YES
  - Message: `feat(interaction): increase drag detection threshold to 40px and timeout to 2s`
  - Files: `Sources/FileStash/Services/DragDetector.swift`
  - Pre-commit: `swift build -c release`

- [ ] 4. Add Localization Keys for New Strings

  **What to do**:
  - Add new localization keys to both `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`
  - New keys needed:
    - `context_menu.restore` = "Restore to Original Location" / "恢复原位"
    - `context_menu.trash` = "Move to Trash" / "移到废纸篓"
    - `empty_state.drag_here` already exists (verify)
  - Verify all existing keys are still present and unchanged
  - Add any additional keys that the new UI introduces (button labels, accessibility descriptions)

  **Must NOT do**:
  - Do NOT remove or change existing localization keys
  - Do NOT use hardcoded strings in Swift code — all new UI text must use `NSLocalizedString`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding keys to two .strings files
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3)
  - **Blocks**: Task 5, Task 6, Task 9
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `Sources/FileStash/en.lproj/Localizable.strings` — English strings (add new keys following this format)
  - `Sources/FileStash/zh-Hans.lproj/Localizable.strings` — Chinese strings (add matching translations)

  **WHY Each Reference Matters**:
  - Must follow exact `.strings` file format: `"key" = "value";`
  - Both files must have identical keys

  **Acceptance Criteria**:
  - [ ] `en.lproj/Localizable.strings` has `context_menu.restore` and `context_menu.trash`
  - [ ] `zh-Hans.lproj/Localizable.strings` has matching Chinese translations
  - [ ] All existing keys are still present
  - [ ] `swift build -c release` exits 0

  **QA Scenarios**:

  ```
  Scenario: Localization keys exist in both files
    Tool: Bash
    Preconditions: Build succeeds
    Steps:
      1. Grep `en.lproj/Localizable.strings` for `context_menu.restore` and `context_menu.trash`
      2. Grep `zh-Hans.lproj/Localizable.strings` for same keys
      3. Verify existing keys (`menu.show_hide`, `menu.open_stash`, `menu.quit`, `empty_state.drag_here`) still present
    Expected Result: All new keys exist in both files, old keys unchanged
    Failure Indicators: Missing keys, changed existing values
    Evidence: .sisyphus/evidence/task-4-localization.txt
  ```

  **Commit**: YES
  - Message: `feat(i18n): add localization keys for context menu`
  - Files: `Sources/FileStash/en.lproj/Localizable.strings`, `Sources/FileStash/zh-Hans.lproj/Localizable.strings`
  - Pre-commit: `swift build -c release`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, check code). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `swift build -c release` and check for warnings. Review all changed files for: force unwraps without safety, empty catches, print statements in prod, unused imports, over-commenting, unnecessary abstractions, generic naming. Verify `#available(macOS 26, *)` guards on all `NSGlassEffectView` usage. Verify `@MainActor` on all UI-mutating code.
  Output: `Build [PASS/FAIL] | Warnings [N] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if possible)
  Build the app. Launch it. Verify every QA scenario from every task. Test: drag from Finder into panel, drag out of panel, click menu bar toggle, right-click context menu, Finder-attach behavior (with/without Accessibility permission), dark/light mode switch. Screenshot each state. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 1**: `feat(data): add delete and restore methods to StashStore` - StashStore.swift, FileSystemProvider.swift
- **Wave 2**: `feat(ui): rewrite views for Liquid Glass and list layout` - StashContentView.swift, DraggableFileItem.swift
- **Wave 3**: `feat(panel): drawer animation and Finder-attached positioning` - StashWindowManager.swift, FinderWindowTracker.swift
- **Wave 4**: `feat(polish): integration and final verification` - all remaining changes

---

## Success Criteria

### Verification Commands
```bash
swift build -c release          # Expected: exits 0, no errors
./build_app.sh                   # Expected: exits 0, FileStash.app created
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] App builds and runs on macOS 14+ with graceful degradation
- [ ] Liquid Glass renders on macOS 26+
- [ ] Finder-attach works with Accessibility permission
- [ ] Mouse-position fallback works without Accessibility permission
- [ ] All animations functional (drawer, spring, scale-fade)
- [ ] Context menu shows correct items
- [ ] All strings localized in English and Chinese