# FileStash Interaction Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 FileStash 的拖拽和吸附手感打磨成“系统级克制”风格，完成 Finder 边缘预告、drop zone 命中反馈和拖出卡片反馈的整套抛光。

**Architecture:** 保持现有 AppKit/SwiftUI 结构不变，只把动效参数和几何从各个视图里收拢到少量 helper。Finder 附着改成三段式 reveal：薄边缘预告、较清晰的 preview、完整吸附；drop zone 和拖出条目的反馈则继续留在各自的视图内部，使用同一组 motion 常量保证节奏一致。测试优先覆盖纯几何和纯值逻辑，最后再做 release build 和 app bundle 的人工烟测。

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, Swift Testing, SwiftPM

---

## File Structure

- Modify: `Sources/FileStash/Services/PanelPlacement.swift`
  Responsibility: Add Finder 附着的 preview geometry，区分 `hiddenRect`、`previewRect` 和 `targetRect`。
- Create: `Sources/FileStash/Services/InteractionMotionStyle.swift`
  Responsibility: Store all motion constants for Finder reveal, drop zone highlight, and drag-out row states.
- Create: `Sources/FileStash/Services/AttachedPanelRevealSequence.swift`
  Responsibility: Bundle the three attached-panel rectangles and their reveal durations into one pure value type.
- Modify: `Sources/FileStash/Services/PanelAnimator.swift`
  Responsibility: Animate Finder-attached panels through hidden -> preview -> target.
- Modify: `Sources/FileStash/StashWindowManager.swift`
  Responsibility: Pass the staged reveal geometry into the animator and keep drag-monitor timing aligned with the animation completion.
- Create: `Sources/FileStash/Views/PanelEdgePreviewView.swift`
  Responsibility: Render the thin edge gloss / preview chrome that appears during Finder attachment.
- Modify: `Sources/FileStash/Views/DropZoneView.swift`
  Responsibility: Apply active/inactive drop-zone chrome with a subtle fill and inner stroke.
- Modify: `Sources/FileStash/DragOut/DraggableFileItem.swift`
  Responsibility: Add drag-begin lift/dim state and ensure success/cancel restore is clean.
- Modify: `Tests/FileStashTests/PanelPlacementTests.swift`
  Responsibility: Lock down attached preview geometry.
- Create: `Tests/FileStashTests/InteractionMotionTests.swift`
  Responsibility: Lock down motion constants and pure reveal-geometry helpers.

## Task 1: Add the motion tests first

**Files:**
- Modify: `Tests/FileStashTests/PanelPlacementTests.swift`
- Create: `Tests/FileStashTests/InteractionMotionTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that expect the new attached-preview geometry and motion constants.

```swift
import AppKit
import Testing
@testable import FileStash

struct InteractionMotionTests {
    @Test func attachedFinderPlacement_exposesThinHiddenPeekAndClearPreview() {
        let finderRect = NSRect(x: 240, y: 220, width: 720, height: 540)
        let placement = PanelPlacement.attachedToFinder(
            finderRect: finderRect,
            panelSize: NSSize(width: 320, height: 420),
            visibleFrame: NSRect(x: 0, y: 80, width: 1440, height: 820),
            offset: 20,
            revealInset: InteractionMotionStyle.attachedPeekInset,
            previewInset: InteractionMotionStyle.attachedPreviewInset
        )

        #expect(placement.hiddenRect == NSRect(x: 652, y: 220, width: 320, height: 540))
        #expect(placement.previewRect == NSRect(x: 668, y: 220, width: 320, height: 540))
        #expect(placement.targetRect == NSRect(x: 960, y: 220, width: 320, height: 540))
    }

    @Test func motionConstants_keepSystemLevelMotionSubtle() {
        #expect(InteractionMotionStyle.dropZoneActiveFillAlpha < 0.2)
        #expect(InteractionMotionStyle.dragLiftScale < 1.0)
        #expect(InteractionMotionStyle.dragLiftAlpha < 1.0)
    }
}
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run: `swift test --filter 'PanelPlacementTests|InteractionMotionTests'`
Expected: compile or assertion failures because `previewRect`, `InteractionMotionStyle`, and `previewInset` do not exist yet.

- [ ] **Step 3: Implement the smallest motion helper surface**

Add `InteractionMotionStyle.swift` and extend `PanelPlacement` with `previewRect` support plus the new `previewInset` argument.

```swift
enum InteractionMotionStyle {
    static let attachedPeekInset: CGFloat = 12
    static let attachedPreviewInset: CGFloat = 28
    static let dropZoneActiveFillAlpha: CGFloat = 0.16
    static let dropZoneActiveStrokeAlpha: CGFloat = 0.22
    static let dragLiftScale: CGFloat = 0.96
    static let dragLiftAlpha: CGFloat = 0.88
}
```

- [ ] **Step 4: Re-run the targeted tests and verify they pass**

Run: `swift test --filter 'PanelPlacementTests|InteractionMotionTests'`
Expected: PASS.

- [ ] **Step 5: Commit the motion helper slice**

```bash
git add Sources/FileStash/Services/PanelPlacement.swift Sources/FileStash/Services/InteractionMotionStyle.swift Tests/FileStashTests/PanelPlacementTests.swift Tests/FileStashTests/InteractionMotionTests.swift
git commit -m "test: lock down FileStash interaction motion geometry"
```

## Task 2: Stage Finder attachment through preview to target

**Files:**
- Modify: `Sources/FileStash/Services/PanelAnimator.swift`
- Modify: `Sources/FileStash/StashWindowManager.swift`
- Create: `Sources/FileStash/Views/PanelEdgePreviewView.swift`

- [ ] **Step 1: Write the failing animation-sequence integration test**

Add a focused test around `AttachedPanelRevealSequence` so the staged reveal frames stay explicit and shared by the animator and the tests.

```swift
@Test func attachedRevealSequence_usesPreviewBeforeFinalTarget() {
    let sequence = AttachedPanelRevealSequence(
        hiddenRect: NSRect(x: 652, y: 220, width: 320, height: 540),
        previewRect: NSRect(x: 668, y: 220, width: 320, height: 540),
        targetRect: NSRect(x: 960, y: 220, width: 320, height: 540)
    )

    #expect(sequence.hiddenRect != sequence.previewRect)
    #expect(sequence.previewRect != sequence.targetRect)
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `swift test --filter InteractionMotionTests`
Expected: failure because the reveal-sequence helper is not wired up yet.

- [ ] **Step 3: Implement staged reveal animation**

Update `PanelAnimator` so attached panels animate in three steps:

1. `hiddenRect` -> very short ease-out
2. `previewRect` -> short settle
3. `targetRect` -> final attach

Keep the existing `PanelAnimator.isAnimating` guard, and keep `DragDetector.shared.startMonitoring()` at the same logical point after the panel is fully visible.

- [ ] **Step 4: Add the edge preview chrome**

Add `PanelEdgePreviewView` as a thin overlay view in `StashWindowManager`'s container hierarchy.

Use it only when the panel is Finder-attached:

```swift
previewView.isHidden = !placement.isFinderAttached
previewView.alphaValue = placement.isFinderAttached ? 1.0 : 0.0
```

Keep the chrome subtle: a thin gloss, not a second card or separate window.

- [ ] **Step 5: Re-run the motion tests**

Run: `swift test --filter 'PanelPlacementTests|InteractionMotionTests'`
Expected: PASS.

- [ ] **Step 6: Commit the attachment reveal slice**

```bash
git add Sources/FileStash/Services/PanelAnimator.swift Sources/FileStash/StashWindowManager.swift Sources/FileStash/Views/PanelEdgePreviewView.swift
git commit -m "feat: stage Finder attachment reveal motion"
```

## Task 3: Polish drop-zone feedback

**Files:**
- Modify: `Sources/FileStash/Views/DropZoneView.swift`
- Modify: `Sources/FileStash/Services/InteractionMotionStyle.swift`
- Modify: `Tests/FileStashTests/InteractionMotionTests.swift`

- [ ] **Step 1: Add the failing style assertions**

```swift
@Test func dropZoneStyle_keepsFeedbackLightweight() {
    #expect(InteractionMotionStyle.dropZoneActiveFillAlpha < 0.2)
    #expect(InteractionMotionStyle.dropZoneActiveStrokeAlpha < 0.3)
}
```

- [ ] **Step 2: Run the drop-zone test and verify it fails**

Run: `swift test --filter InteractionMotionTests`
Expected: failure until the style constants exist and `DropZoneNSView` uses them.

- [ ] **Step 3: Implement the active/inactive chrome**

Make `DropZoneNSView` switch between:

```swift
inactive:
    layer?.backgroundColor = .clear
    layer?.borderWidth = 0

active:
    layer?.backgroundColor = NSColor.white.withAlphaComponent(InteractionMotionStyle.dropZoneActiveFillAlpha).cgColor
    layer?.borderWidth = 1
    layer?.borderColor = NSColor.white.withAlphaComponent(InteractionMotionStyle.dropZoneActiveStrokeAlpha).cgColor
```

- [ ] **Step 4: Re-run the targeted tests**

Run: `swift test --filter InteractionMotionTests`
Expected: PASS.

- [ ] **Step 5: Commit the drop-zone polish**

```bash
git add Sources/FileStash/Views/DropZoneView.swift Sources/FileStash/Services/InteractionMotionStyle.swift Tests/FileStashTests/InteractionMotionTests.swift
git commit -m "feat: polish FileStash drop zone feedback"
```

## Task 4: Polish drag-out item feedback

**Files:**
- Modify: `Sources/FileStash/DragOut/DraggableFileItem.swift`
- Modify: `Sources/FileStash/Services/InteractionMotionStyle.swift`
- Modify: `Tests/FileStashTests/InteractionMotionTests.swift`

- [ ] **Step 1: Add the failing drag-state assertions**

```swift
@Test func dragStyle_keepsRowsSubtleWhileDragging() {
    #expect(InteractionMotionStyle.dragLiftScale > 0.9)
    #expect(InteractionMotionStyle.dragLiftScale < 1.0)
    #expect(InteractionMotionStyle.dragLiftAlpha < 1.0)
}
```

- [ ] **Step 2: Run the drag-style test and verify it fails**

Run: `swift test --filter InteractionMotionTests`
Expected: failure until the row drag constants exist and are used.

- [ ] **Step 3: Implement the drag-begin / drag-end state helpers**

Update `DraggableFileItemView` so drag start applies the lifted state before `beginDraggingSession`, and `draggingSession(_:endedAt:operation:)` always restores identity on cancel.

Use the existing success animation path, but make the values come from `InteractionMotionStyle` instead of hard-coded numbers.

- [ ] **Step 4: Re-run the targeted tests**

Run: `swift test --filter InteractionMotionTests`
Expected: PASS.

- [ ] **Step 5: Commit the drag-out polish**

```bash
git add Sources/FileStash/DragOut/DraggableFileItem.swift Sources/FileStash/Services/InteractionMotionStyle.swift Tests/FileStashTests/InteractionMotionTests.swift
git commit -m "feat: polish FileStash drag-out feedback"
```

## Task 5: Final verification

**Files:**
- No new files expected

- [ ] **Step 1: Run the combined motion test slice**

Run: `swift test --filter 'PanelPlacementTests|InteractionMotionTests'`
Expected: PASS.

- [ ] **Step 2: Run the release build**

Run: `swift build -c release`
Expected: PASS.

- [ ] **Step 3: Rebuild the app bundle**

Run: `./build_app.sh`
Expected: PASS and regenerate `FileStash.app`.

- [ ] **Step 4: Smoke-check the packaged app**

Run:

```bash
open -na /Users/ray/Documents/trae_projects/MacApps/FileStash/FileStash.app
sleep 2
pgrep -x FileStash
```

Expected: one or more `FileStash` PIDs listed.

- [ ] **Step 5: Commit the final polish slice**

```bash
git add Sources Tests build_app.sh
git commit -m "feat: finish FileStash interaction polish"
```
