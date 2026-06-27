# FileStash Interaction Polish Design

**Goal:** 把 FileStash 的拖拽和吸附手感收成“系统级克制”风格，让 Finder 附着预告、drop zone 命中反馈、拖出卡片反馈都更轻、更准、更连贯。

**Architecture:** 继续沿用现有 AppKit + SwiftUI 结构，不引入新窗口或全局动效框架。把动效边界收敛到现有的 `PanelPlacement`、`PanelAnimator`、`DropZoneNSView` 和 `DraggableFileItemView`，再加一个很小的 reveal sequence helper，用一组小的 motion 常量统一节奏、透明度和缩放值。Finder 附着仍然由 `StashWindowManager` 触发，但显示过程会变成“薄边缘预告 -> 更清晰的露出 -> 完整吸附”的三段式体验。

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, Swift Testing, SwiftPM

---

## Scope

### In Scope

- Finder 附着时的边缘预告和吸附节奏
- drop zone 的轻量高亮、内侧描边、退出回收
- 拖出文件条目的起手抬升、拖中态、成功/取消收尾
- 相关几何与 motion 常量的单元测试

### Out of Scope

- 新的设置页或动效偏好项
- 新的浮窗、教程窗或独立提示层
- 与 Finder 以外应用的额外联动

## Motion Design

### 1. Finder 附着预告

Finder 附着不再只依赖单次滑入。`PanelPlacement` 会区分三段几何：

- `hiddenRect`：非常薄的边缘预告，只露出一条窄缝
- `previewRect`：比 `hiddenRect` 更清晰的露出，确认“这里会吸附”
- `targetRect`：完整吸附位置，与 Finder 形成整体

`PanelAnimator` 会按顺序播放这三段状态，保持短、轻、向右或向左的自然推进。当前已有的 Finder 高度对齐、边缘吸附和关闭同步行为保持不变。

### 2. Drop Zone 命中反馈

`DropZoneNSView` 只做两种状态：`inactive` 和 `active`。

- `active` 时使用轻微提亮、很浅的填充和 1px 级别的内侧描边
- 离开或投放完成后立刻回到 `inactive`
- 不做夸张闪烁，不单独弹出文字提示

### 3. 拖出卡片反馈

`DraggableFileItemView` 在拖拽起手时进入“拖中态”：

- 轻微抬升
- 轻微缩小
- 略微降低透明度

拖拽成功后继续沿用现有的淡出/移除收尾；拖拽取消时恢复到正常状态，不留下残余缩放或透明度。

## Components

### `Sources/FileStash/Services/PanelPlacement.swift`

继续负责 Finder 附着几何，但会补充预告阶段需要的中间矩形，让“薄边缘预告”和“完整吸附”都由同一个几何模型描述。

### `Sources/FileStash/Services/InteractionMotionStyle.swift`

负责保存这轮抛光的 motion 常量，例如 Finder 预告的 inset、drop zone 的亮度、拖出条目的缩放与透明度。

### `Sources/FileStash/Services/PanelAnimator.swift`

负责执行三段式附着动画，保持动画时长短、过渡干净，避免和 `StashWindowManager` 的生命周期逻辑耦合。

### `Sources/FileStash/Services/AttachedPanelRevealSequence.swift`

负责把 Finder 附着的三段矩形和对应时长打包成一个纯值对象，方便动画和测试共享同一套 reveal 逻辑。

### `Sources/FileStash/Views/PanelEdgePreviewView.swift`

负责绘制 Finder 附着时的薄边缘 gloss，让 preview 阶段有一眼能感知的边缘反馈，但不变成第二个窗口或卡片。

### `Sources/FileStash/StashWindowManager.swift`

负责选择何时播放附着预告，何时恢复 DragDetector，何时让面板进入稳定展示态。这里不引入新的全局状态，只补最小的动效协同。

### `Sources/FileStash/Views/DropZoneView.swift`

负责投放区高亮状态，不改拖放协议本身，只调整视觉反馈。

### `Sources/FileStash/DragOut/DraggableFileItem.swift`

负责文件条目的拖拽起手和结束收尾状态，不改现有 `NSDraggingSession` 流程。

### `Tests/FileStashTests/PanelPlacementTests.swift`

补齐 Finder 附着三段矩形的几何覆盖，确保薄边缘预告和最终吸附都可预测。

### `Tests/FileStashTests/InteractionMotionTests.swift`

新增 motion 常量和状态 helper 的单元测试，覆盖透明度、缩放和预告宽度这类纯值逻辑。

## Data Flow

1. `StashWindowManager` 判断 Finder 附着并拿到 `PanelPlacement`
2. `PanelAnimator` 先展示 `hiddenRect`，再过渡到 `previewRect`，最后到 `targetRect`
3. `DropZoneNSView` 在文件进入时切换成 active 样式，退出或投放后复位
4. `DraggableFileItemView` 在拖拽起手时进入拖中态，在结束时恢复或执行成功收尾

## Error Handling

- 如果动画正在进行，保持现有 `PanelAnimator` 的单实例保护，不叠加新的动画实例
- 如果 Finder 附着状态在动画过程中消失，继续沿用现有关闭路径，不尝试跳转到别的 Finder 窗口
- 如果拖放或拖出取消，必须恢复到干净的 idle 视觉状态

## Testing

- 几何逻辑由 `PanelPlacementTests` 覆盖
- motion 常量和纯 helper 由 `InteractionMotionTests` 覆盖
- 最终还要做一次 release build 和 `.app` 启动检查，人工确认三处体验：
  - Finder 边缘预告先出现再完整吸附
  - drop zone 进入/退出的高亮足够轻
  - 拖出条目在起手、取消、成功时状态干净

## Non-Goals

- 不引入更复杂的设置项
- 不做重视觉改版
- 不改 stash 数据层或 Finder 身份跟踪的 P0 逻辑
