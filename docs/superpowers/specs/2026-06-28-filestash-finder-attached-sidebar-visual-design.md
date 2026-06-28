# FileStash Finder-Attached Sidebar Visual Design

**Goal:** 把 FileStash 的 Finder 附着面板收成“Finder 自带附属边栏”风格：继续沿用当前吸附机制和独立窗口模型，但把 FileStash 自身的材质、圆角、阴影、header 玻璃条、空状态和文件列表观感统一到 Finder 的视觉家族里。

**Architecture:** 保持现有 `NSPanel` + AppKit/SwiftUI 结构，不改 `PanelPlacement`、附着几何、拖拽探测、stash/restore 数据逻辑，也不尝试让 FileStash 真正压到 Finder 窗口后面。设计改造只发生在 FileStash 自身的视觉层：`GlassBackgroundView` 提供更浅的系统材质基底，`StashContentView` 重做 header 与空状态，`StashWindowManager` 只负责承载新的 pane chrome 和 header 叠层，`FileGridItem` / `DraggableFileItemView` 则统一内容区的 hover 与拖拽观感。

**Tech Stack:** Swift 6.2, AppKit, SwiftUI, SwiftPM

---

## Scope

### In Scope

- Finder attached 状态下的 FileStash pane 外观
- FileStash pane 的四角、边线、阴影和浅玻璃材质
- `FileStash` 标题区的悬浮 glass strip
- empty state 的图标、文案、留白和对比度
- 文件列表项的 hover、拖拽 lift 和文字层级统一
- menu bar 弹出与 Finder attached 两种展示模式下的 pane 视觉一致性

### Out of Scope

- 任何附着算法、动画时序或 panel 放置逻辑改动
- 真实 underlap / 把 FileStash 压进 Finder 后面的跨窗口层级方案
- stash / restore / drag-out 的数据层和行为改动
- 新设置项、主题切换或用户可配置的视觉参数
- Finder 自身窗口的任何修改

## Confirmed Decisions

这份设计文档建立在以下已确认的决策上：

- 整体方向选择“更像 Finder 自带边栏”，不是独立工具卡片
- 视觉基线采用融合式附着方向，但不依赖真实窗口重叠
- `FileStash` 标题区采用 `Balanced Glass` 方案
- 保留 FileStash 自己的四个圆角
- 继续沿用当前吸附方案，只改变 FileStash 本身的视觉效果

## Visual Model

### 1. Window Relationship

FileStash 在 Finder 旁边时，仍然读成一个独立 pane，但不是一张厚重的悬浮卡片。它应该更像 Finder 同一视觉家族里的附属边栏：

- 与 Finder 在亮度、材质和线条上保持近亲关系
- 仍然清楚地属于 FileStash，而不是伪装成 Finder 自己的内部视图
- 不靠真实 underlap 营造无缝，只靠 pane 自身的 chrome 收敛差异

最终读感应该是：

> 这是一个独立的 FileStash 边栏，但它的玻璃感、圆角、header 悬浮方式和内容层级都像 Finder 自带的原生扩展。

### 2. Corner Ownership

FileStash 保留四个圆角，不采用“只有右侧圆角”的半拼接窗体方案。原因是当前产品要继续沿用现有吸附机制和独立 pane 模型，不能把视觉前提建立在 Finder 与 FileStash 的真实窗口重叠上。

因此：

- 四角全部保留
- 圆角半径向 Finder 靠拢，避免当前 pane 读成工具型 HUD
- 通过更轻的边线、阴影和材质，而不是删角，来减少“第二张厚卡片”的感觉

## Surface Design

### 1. Base Material

当前 fallback 材质偏 `HUD`，太深、太灰，也太像独立工具窗。新的 pane 基底要更浅、更白、更低对比：

- 整体明度接近 Finder 窗体表面
- 饱和度较低
- 微弱透出下层应用颜色
- 不做夸张 frosted 演示感

在视觉上，它应更像 Finder 自带侧栏表面的浅玻璃，而不是一块悬浮 utility HUD。

### 2. Border and Shadow

主 pane 的轮廓要收轻：

- 外边线使用极淡 hairline
- 整体阴影减轻，只保留柔和的分离感
- 左边靠 Finder 一侧不强调轮廓
- 右侧和四角承担主要边界识别

目标不是把 pane 做“消失”，而是让它不再先被识别成一张厚重浮卡。

### 3. Radius

圆角半径应接近 Finder 这类现代 macOS 窗体的区间，偏 `18-20`。这会让 pane 和 Finder 更像同一套系统语言，而不是一个 Finder 窗体旁边挂着一张更小、更硬的自定义卡片。

## Header Design

### 1. Header Role

`FileStash` 标题区不是普通扁平 header，也不是一个独立工具栏。它的角色是：

> 一条轻微悬浮在 pane 主体之上的半透明 glass strip。

它需要同时满足三件事：

- 保持极简
- 清楚地成为 pane 的控制层
- 借用 Finder 左侧边栏顶部那种轻玻璃、浅阴影、半浮起的语义

### 2. Balanced Glass Treatment

最终选用的 header 处理是 `Balanced Glass`：

- 有明确但克制的悬浮感
- 有浅阴影和很轻的内高光
- 半透明，能让 pane 自身以及背后应用的颜色微弱渗透
- 不做厚重 glossy capsule
- 不弱到完全融掉、看不出控制层

这条 glass strip 应位于 pane 主体内部上方，读成 pane 自己的悬浮控制条，而不是 Finder 标题栏的一部分。

### 3. Header Geometry

- header 高度低于传统内容 header，更接近 Finder 工具条语义
- 左右 inset 更克制
- 圆角小于 pane 外圆角，但仍有柔和玻璃轮廓
- 与 pane 顶边之间保留很小的悬浮距离

### 4. Close Button

关闭按钮继续保留极简，但不再以单独小圆泡的方式突出。它应融进 glass strip：

- 默认状态低对比度
- hover 时略微提亮
- 与标题条共享相同的玻璃与阴影语义

## Content Area

### 1. Empty State

empty state 要更像 Finder pane 的空内容，而不是组件型空状态：

- 图标尺寸略收，保持系统感
- 图标与文字颜色降低对比度
- 垂直布局更疏朗
- 留白加大，让 pane 有“呼吸感”

文案继续极简，不增加解释性 UI。

### 2. File List

文件列表出现后，也要延续同一视觉语义：

- 行高偏紧凑，接近 Finder 侧栏 / 辅助 pane 的效率感
- hover 只做极浅底色
- 图标、文件名和间距统一
- 不引入额外卡片化块面

### 3. Drag-Out State

已有拖拽 lift 可以保留，但它要服从新的 pane 美术层级：

- 透明度、缩放和 hover 的强度都不能比 header 更抢戏
- 拖拽反馈依旧轻、系统、克制

## Implementation Mapping

### `Sources/FileStash/Views/GlassBackgroundView.swift`

- 替换当前偏 HUD 的 fallback 材质
- 统一 pane 背景的浅玻璃基底
- 更新圆角值以匹配 Finder 家族的外轮廓

### `Sources/FileStash/Views/StashContentView.swift`

- 重构 header 结构，使其成为一条悬浮的 glass strip
- 调整标题、关闭按钮、header 内边距
- 调整 divider 和内容区留白
- 收紧 empty state 的图标、文字和垂直布局

### `Sources/FileStash/StashWindowManager.swift`

- 保留现有 panel 创建、吸附和展示逻辑
- 调整 pane 自身承载 chrome 的方式
- 确保新 header 叠层在 container hierarchy 中有正确的层级
- 只改变视觉结构，不改变窗口行为

### `Sources/FileStash/Views/FileGridItem.swift`

- 对齐新的内容区 spacing 和 hover 语义

### `Sources/FileStash/DragOut/DraggableFileItem.swift`

- 让 row hover / drag-lift 与新的浅玻璃 pane 观感一致
- 避免沿用过重的背景强调

## Acceptance Criteria

实现完成后，以下几项必须同时成立：

1. FileStash attached 到 Finder 时，仍清楚是独立 pane，但明显属于 Finder 同一家族。
2. FileStash 保留四个圆角，且不再读成厚重的第二张浮卡。
3. `FileStash` header 明确呈现 `Balanced Glass`：
   - 轻微悬浮
   - 半透明
   - 有浅阴影
   - 能微弱透出下层颜色
4. empty state 和文件列表与 pane 新材质匹配，不再显得像旧工具窗内容。
5. menu bar 弹出场景与 Finder attached 场景下，pane 的视觉语言一致。
6. 现有吸附、拖拽、stash/restore 行为不受影响。

## Risks and Non-Goals

### Risks

- 如果 header 玻璃过强，会重新读成“独立贴上的 capsule”
- 如果主体玻璃过弱，会回到普通浅色卡片
- 如果阴影过重，会放大独立浮卡感

### Explicit Non-Goals

- 不追求跨窗口真实无缝
- 不通过窗口层级技巧把 pane 压进 Finder 后面
- 不改变 panel 的焦点、激活或附着规则

## Testing and Review

这轮修改完成后需要做的验证：

- 人工检查 Finder attached 视觉效果
- 人工检查 menu bar 弹出视觉效果
- 人工检查空状态、文件列表、hover、拖拽 lift 的整体一致性
- 跑现有 SwiftPM 测试，确认纯视觉改动没有影响已有行为
