# FileStash Comprehensive Optimization

## TL;DR

> **Quick Summary**: 全面优化 FileStash macOS 菜单栏应用 — 修复数据安全漏洞、重构核心逻辑为 TDD、引入依赖注入、添加文件监听和本地化基础设施，使应用更可靠、更易维护。
> 
> **Deliverables**:
> - 修复 StashItem 身份标识（稳定 ID 替代随机 UUID）
> - 原子化元数据写入（防崩溃丢数据）
> - 替换 finalizeDrag 硬编码延迟为轮询机制
> - 错误处理从 `try?` 升级为 `do/catch` + 日志
> - 图标缓存、代码去重、魔法数字提取
> - FileSystemProvider 协议 + mock 实现用于依赖注入
> - DispatchSourceFileSystemObject 文件监听
> - NSLocalizedString 本地化基础设施
> - XCTest 测试套件覆盖核心逻辑
> - 修复 Bundle ID 占位符、添加 .gitignore
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 5 waves
> **Critical Path**: T1(test infra) → T4(StashItem identity) → T6(TDD error handling) → T8(DI refactor) → T11(localization) → F1-F4

---

## Context

### Original Request
用户要求对 FileStash macOS 菜单栏应用进行"全面优化"，覆盖可靠性、用户体验和代码质量。

### Interview Summary
**Key Discussions**:
- 优先级：UX > 可靠性 > 代码可维护性
- 测试策略：TDD（RED → GREEN → REFACTOR）
- 单例重构：重构成 Protocol + 依赖注入
- 本地化：NSLocalizedString 基础设施 + 中英文本地化
- 不包含：新功能（快捷键、撤销等）、UI 视觉重设计、App 沙盒/公证

### Metis Review
**Identified Gaps** (addressed):
- StashItem 用 UUID 做 Identifiable 会导致每次 refreshItems 全量重渲染 → 改用 url.path 作为稳定 ID
- `unstash(item:)` 是死代码，只删除不还原 → 移除
- NSFileCoordinator 不适用于 finalizeDrag 场景 → 改用轮询（0.05s 间隔，2s 超时）
- 元数据 save 不是原子操作 → write-to-temp-then-rename
- FileManager.default.urls `.first!` 强制解包 → 安全解包
- AppDelegate.openStashFolder() 路径重复构建 → 使用 StashStore.shared.stashDirectory
- 文件从 stash 拖回 stash 会创建重复 → 添加检测和拒绝逻辑
- 原始目录不存在时 moveItem 会失败 → 创建目录或回退到默认位置

---

## Work Objectives

### Core Objective
全面提升 FileStash 的可靠性、用户体验和代码可维护性，同时保持零外部依赖和现有运行时行为不变。

### Concrete Deliverables
- `Package.swift` 包含测试目标
- `Tests/FileStashTests/` 目录下的完整测试套件
- `StashItem` 使用稳定 ID（不再每次 refresh 生成新 UUID）
- `StashStore` 的错误处理从 `try?` 升级为 `do/catch` + `os.Logger`
- 元数据写入原子化
- `finalizeDrag` 使用轮询机制替代固定延迟
- `FileSystemProvider` 协议和 mock 实现
- `Localizable.strings` (en + zh-Hans)
- `DispatchSourceFileSystemObject` 文件监听
- 修复的 Bundle ID 和 .gitignore

### Definition of Done
- [ ] `swift build` 通过
- [ ] `swift test` 通过（所有测试 GREEN）
- [ ] `swift build -c release && ./build_app.sh` 生成可运行的 `.app`
- [ ] 手动验证：拖入文件 → 面板显示 → 拖出文件 → 文件还原到原位

### Must Have
- StashItem 稳定身份（url.path 替代 UUID）
- 原子化元数据写入
- do/catch + os.Logger 替代 try?
- finalizeDrag 轮询替代固定延迟
- FileSystemProvider 协议（仅此一个协议）
- 去重 uniqueURL 方法
- 魔法数字提取为常量
- NSLocalizedString 迁移所有中文字符串
- 测试目标 + 核心逻辑测试
- 修复 Bundle ID 占位符
- .gitignore + git init

### Must NOT Have (Guardrails)
- 不触碰 NSPanel 配置（.borderless, .nonactivatingPanel, .floating, hidesOnDeactivate, canJoinAllSpaces）
- 不添加任何外部依赖
- 不只为不需要 mock 的类型创建协议（目标：仅 StashStore 的文件系统访问需要协议）
- 不添加新 UI 元素、动画或视觉变更
- 不修改拖拽检测阈值（12px, 1s, 0.03s）除非有实证证据
- 不使用 NSFileCoordinator 替代 finalizeDrag
- 不添加自定义错误枚举（超出测试断言需要的范围）
- 不添加 .stringsdict、语言切换 UI、RTL 支持
- 不添加 LRU 缓存或内存压力处理（图标缓存用简单 Dictionary 即可）

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (needs to be created)
- **Automated tests**: YES (TDD)
- **Framework**: XCTest (SPM built-in)
- **If TDD**: Each task follows RED (failing test) → GREEN (minimal impl) → REFACTOR

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Library/Module**: Use Bash (swift test, swift build) — compile, run tests, check output
- **App Integration**: Use Bash (./build_app.sh) — build binary, verify .app exists, verify it launches
- **File Operations**: Use Bash — create temp files, verify metadata persistence, test edge cases

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - foundation + critical bug fixes):
├── Task 1: Add test target to Package.swift [quick]
├── Task 2: Fix StashItem identity — stable ID from url.path [quick]
├── Task 3: Atomic metadata write + safe FileManager URL unwrap [quick]
├── Task 4: Remove dead code unstash(item:) [quick]
└── Task 5: Fix AppDelegate.openStashFolder path duplication [quick]

Wave 2 (After Wave 1 - TDD core logic, MAX PARALLEL):
├── Task 6: TDD — Error handling upgrade (try? → do/catch + Logger) (depends: 1, 3) [deep]
├── Task 7: TDD — finalizeDrag polling replacement (depends: 1, 2) [deep]
├── Task 8: TDD — uniqueURL dedup + edge cases (depends: 1, 4) [unspecified-high]
├── Task 9: Icon caching in StashStore (depends: 1, 2) [quick]
└── Task 10: Extract magic numbers to constants (depends: 1) [quick]

Wave 3 (After Wave 2 - DI refactoring + file watching):
├── Task 11: FileSystemProvider protocol + mock (depends: 6, 7) [deep]
├── Task 12: Inject StashStore through DI, remove .shared from code paths (depends: 11) [unspecified-high]
└── Task 13: DispatchSourceFileSystemObject file watching (depends: 2, 9) [unspecified-high]

Wave 4 (After Wave 3 - localization + integration):
├── Task 14: NSLocalizedString infrastructure + string migration (depends: 12) [unspecified-high]
└── Task 15: Fix Bundle ID + .gitignore + git init (depends: none) [quick]

Wave FINAL (After ALL tasks — 4 parallel reviews):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
→ Present results → Get explicit user okay

Critical Path: T1 → T6/T7 → T11 → T12 → T14
Parallel Speedup: ~55% faster than sequential
Max Concurrent: 5 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 6,7,8,9,10 | 1 |
| 2 | — | 7,9,13 | 1 |
| 3 | — | 6 | 1 |
| 4 | — | 8 | 1 |
| 5 | — | — | 1 |
| 6 | 1,3 | 11 | 2 |
| 7 | 1,2 | 11 | 2 |
| 8 | 1,4 | — | 2 |
| 9 | 1,2 | 13 | 2 |
| 10 | 1 | — | 2 |
| 11 | 6,7 | 12 | 3 |
| 12 | 11 | 14 | 3 |
| 13 | 2,9 | — | 3 |
| 14 | 12 | — | 4 |
| 15 | — | — | 4 |

### Agent Dispatch Summary

- **Wave 1**: **5 tasks** — T1-T4 → `quick`, T5 → `quick`
- **Wave 2**: **5 tasks** — T6,T7 → `deep`, T8 → `unspecified-high`, T9,T10 → `quick`
- **Wave 3**: **3 tasks** — T11 → `deep`, T12 → `unspecified-high`, T13 → `unspecified-high`
- **Wave 4**: **2 tasks** — T14 → `unspecified-high`, T15 → `quick`
- **FINAL**: **4 tasks** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. Add XCTest target to Package.swift

  **What to do**:
  - Add a `.testTarget(name: "FileStashTests", dependencies: ["FileStash"])` to `Package.swift`
  - Create `Tests/FileStashTests/` directory
  - Add a minimal test file `StashStoreTests.swift` with one placeholder test that asserts `true`
  - Run `swift build` and `swift test` to verify the test infrastructure works
  - Add `.build/` and `*.xcodeproj/` to a new `.gitignore` file at project root

  **Must NOT do**:
  - Don't write actual test logic yet (that's Wave 2)
  - Don't add any external test dependencies
  - Don't create more test files than the one placeholder

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file edit (Package.swift) + directory creation + one test file
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2-5)
  - **Blocks**: Tasks 6, 7, 8, 9, 10
  - **Blocked By**: None

  **References**:
  - `Package.swift` — Current SPM configuration, need to append test target
  - AGENTS.md → "No tests exist" — Confirms no test target exists yet
  - Swift Package Manager docs: `.testTarget` syntax

  **Acceptance Criteria**:
  - [ ] `swift build` exits 0
  - [ ] `swift test` exits 0 with 1 test passing
  - [ ] `Tests/FileStashTests/StashStoreTests.swift` exists with one `XCTestCase` method

  **QA Scenarios**:

  ```
  Scenario: Test infrastructure compiles and runs
    Tool: Bash
    Preconditions: Project root is current directory
    Steps:
      1. Run `swift build` → exit code 0
      2. Run `swift test` → exit code 0, output contains "Executed 1 test"
    Expected Result: Both commands succeed
    Failure Indicators: Build error, test failure, wrong test count
    Evidence: .sisyphus/evidence/task-1-test-infra.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `chore: add XCTest target to Package.swift`
  - Files: `Package.swift`, `Tests/FileStashTests/StashStoreTests.swift`, `.gitignore`
  - Pre-commit: `swift build && swift test`

- [x] 2. Fix StashItem identity — use stable ID from url.path

  **What to do**:
  - Change `StashItem` from `let id = UUID()` to use `url.path` as the stable identifier
  - Make `StashItem` conform to `Identifiable` with `id` being the file path string
  - Update `Equatable` to use the stable ID
  - This fixes: SwiftUI's `ForEach` re-creating all views on every `refreshItems()` call, which loses drag state and causes visual flicker

  **Must NOT do**:
  - Don't add new properties to `StashItem`
  - Don't change the `url`, `name`, `icon`, `originalURL` properties

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single struct definition change, 2-3 lines
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3-5)
  - **Blocks**: Tasks 7, 9, 13
  - **Blocked By**: None

  **References**:
  - `Sources/FileStash/StashStore.swift:4-14` — Current `StashItem` struct with `let id = UUID()` causing identity instability
  - Metis review finding A6: "StashItem.id = UUID() causes full re-render on every refresh"

  **Acceptance Criteria**:
  - [ ] `StashItem.id` is derived from `url.path`, not `UUID()`
  - [ ] `swift build` succeeds
  - [ ] Calling `refreshItems()` twice produces items with identical IDs

  **QA Scenarios**:

  ```
  Scenario: Stable identity across refreshes
    Tool: Bash
    Preconditions: FileStash builds successfully
    Steps:
      1. Build project: `swift build`
      2. Verify StashItem.id type is String (not UUID) by grepping the source
      3. Verify no `UUID()` appears in StashItem definition
    Expected Result: StashItem uses url.path as id
    Failure Indicators: UUID() still present, build failure
    Evidence: .sisyphus/evidence/task-2-stashitem-identity.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `fix: use stable url.path as StashItem identifier instead of random UUID`
  - Files: `Sources/FileStash/StashStore.swift`
  - Pre-commit: `swift build`

- [x] 3. Atomic metadata write + safe FileManager URL unwrap

  **What to do**:
  - Replace `saveMetadata()` implementation: write to temporary file first, then `FileManager.default.replaceItemAt()` to atomically swap
  - Replace `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!` with safe unwrap: `guard let appSupport = ... .first else { return [] }` (return empty items)
  - In `stashDirectory` computed property, cache the result (avoid re-computing each time)

  **Must NOT do**:
  - Don't use `NSFileCoordinator` for metadata writes
  - Don't add custom error enums
  - Don't change the metadata format (still `[String: String]` as JSON)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small targeted changes to 2-3 methods
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - `Sources/FileStash/StashStore.swift:22-25` — `stashDirectory` with force unwrap `.first!`
  - `Sources/FileStash/StashStore.swift:48-52` — Current `saveMetadata()` that writes directly (non-atomic)
  - Metis finding E1: "crash during saveMetadata can corrupt data"

  **Acceptance Criteria**:
  - [ ] `saveMetadata()` writes to temp file then replaces atomically
  - [ ] No `!` force unwrap on `FileManager.default.urls(for:).first`
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: Atomic metadata write survives interruption
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. Verify `replaceItemAt` or equivalent atomic write pattern appears in StashStore.swift
      2. Verify no `.first!` force unwrap on FileManager URL access
      3. Build: `swift build` → exit 0
    Expected Result: Atomic write pattern in place, no force unwraps on FileManager URLs
    Failure Indicators: Direct write still present, force unwrap still exists
    Evidence: .sisyphus/evidence/task-3-atomic-metadata.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `fix: atomic metadata write and safe FileManager URL unwrap`
  - Files: `Sources/FileStash/StashStore.swift`
  - Pre-commit: `swift build`

- [x] 4. Remove dead code — unstash(item:) method

  **What to do**:
  - Remove the `unstash(item:)` method from `StashStore.swift` (lines 133-145)
  - This method deletes files without restoring them, which is dangerous dead code
  - It's never called from any view — the actual restore logic is in `finalizeDrag(item:)`
  - Search entire codebase for any `unstash` references to confirm it's dead

  **Must NOT do**:
  - Don't replace it with a proper restore method (that's not in scope)
  - Don't add any new methods

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Delete 13 lines, verify no references
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-3, 5)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:
  - `Sources/FileStash/StashStore.swift:133-145` — The `unstash(item:)` method that deletes without restoring
  - Metis finding E7: "unstash(item:) is dead code — never called, and it deletes without restoring"

  **Acceptance Criteria**:
  - [ ] `unstash` method removed from `StashStore.swift`
  - [ ] No references to `unstash` anywhere in codebase
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: Dead code removal doesn't break build
    Tool: Bash
    Preconditions: None
    Steps:
      1. `grep -r "unstash" Sources/` → returns nothing
      2. `swift build` → exit 0
    Expected Result: No references to unstash, build succeeds
    Failure Indicators: Reference found, build failure
    Evidence: .sisyphus/evidence/task-4-remove-dead-code.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `refactor: remove dead unstash(item:) method`
  - Files: `Sources/FileStash/StashStore.swift`
  - Pre-commit: `swift build`

- [x] 5. Fix AppDelegate.openStashFolder path duplication

  **What to do**:
  - Change `AppDelegate.openStashFolder()` (line 61-62) to use `StashStore.shared.stashDirectory` instead of independently constructing the path
  - This eliminates a potential divergence between `StashStore`'s path and `AppDelegate`'s path

  **Must NOT do**:
  - Don't restructure AppDelegate beyond this one-line change
  - Don't add any new methods or properties

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single line change
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1-4)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `Sources/FileStash/AppDelegate.swift:60-63` — Current `openStashFolder()` duplicating the stashDirectory path
  - `Sources/FileStash/StashStore.swift:22-25` — `stashDirectory` computed property that's the single source of truth
  - Metis finding E9: "AppDelegate.openStashFolder() duplicates path construction"

  **Acceptance Criteria**:
  - [ ] `openStashFolder()` uses `StashStore.shared.stashDirectory` directly
  - [ ] No independent path construction remains in `AppDelegate`
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: Path duplication eliminated
    Tool: Bash
    Preconditions: None
    Steps:
      1. `grep -n "applicationSupportDirectory" Sources/FileStash/AppDelegate.swift` → returns nothing
      2. `grep -n "stashDirectory" Sources/FileStash/AppDelegate.swift` → returns the line using StashStore.shared.stashDirectory
      3. `swift build` → exit 0
    Expected Result: AppDelegate uses StashStore's path, no independent construction
    Failure Indicators: Still has FileManager path construction in AppDelegate
    Evidence: .sisyphus/evidence/task-5-path-dedup.txt
  ```

  **Commit**: YES (groups with Wave 1)
  - Message: `fix: use StashStore.shared.stashDirectory in AppDelegate instead of duplicating path`
  - Files: `Sources/FileStash/AppDelegate.swift`
  - Pre-commit: `swift build`

- [x] 6. TDD — Error handling upgrade (try? → do/catch + Logger)

  **What to do**:
  - RED: Write tests in `Tests/FileStashTests/StashStoreTests.swift` that verify:
    - `stash(url:)` logs an error when move fails AND copy fails
    - `stash(url:)` succeeds when move fails but copy succeeds
    - `stash(url:)` succeeds when move succeeds directly
    - `loadMetadata()` returns empty dict when file doesn't exist or is corrupt
    - `saveMetadata()` writes valid JSON that can be read back
  - GREEN: Replace all `try?` in `StashStore.swift` with `do/catch` blocks that use `os.Logger` (import `os`) for error logging
  - REFACTOR: Clean up any redundant error handling patterns
  - Use `os.Logger(subsystem: "com.FileStash", category: "StashStore")` for structured logging

  **Must NOT do**:
  - Don't create custom error enums (beyond what's needed for test assertions)
  - Don't add user-facing error UI
  - Don't change the public API of `StashStore`
  - Don't log in test assertions — test behavior, not logs

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: TDD cycle with multiple tests, need careful red-green-refactor
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 1, 3

  **References**:
  - `Sources/FileStash/StashStore.swift` — All `try?` locations: line 37 (`ensureDirectoryExists`), lines 41-42 (`loadMetadata`), lines 49-51 (`saveMetadata`), lines 81-88 (`stash`), lines 85-86 (`stash` copy fallback), line 117 (`finalizeDrag` moveItem), line 109 (`finalizeDrag` fileExists check)
  - Swift `os.Logger` API: `import os`, `let logger = Logger(subsystem:category:)`, `logger.error("message")`

  **Acceptance Criteria**:
  - [ ] No `try?` remains in `StashStore.swift`
  - [ ] All `do/catch` blocks log errors via `os.Logger`
  - [ ] `swift test` passes with all new error handling tests GREEN
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: Error handling works for file operations
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift build` → exit 0
      2. `swift test` → all tests pass, output shows new test methods
      3. `grep -c "try?" Sources/FileStash/StashStore.swift` → count is 0
      4. `grep -c "Logger" Sources/FileStash/StashStore.swift` → count > 0
    Expected Result: No try? in StashStore, Logger present, all tests pass
    Failure Indicators: try? still present, tests fail, Logger not found
    Evidence: .sisyphus/evidence/task-6-error-handling.txt

  Scenario: Metadata persistence is robust
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift test` → tests for loadMetadata and saveMetadata pass
      2. Verify test coverage includes: non-existent file returns empty dict, corrupt JSON returns empty dict, round-trip write/read works
    Expected Result: Metadata tests cover corruption and missing file cases
    Failure Indicators: Tests missing or failing
    Evidence: .sisyphus/evidence/task-6-metadata-tests.txt
  ```

  **Commit**: YES (groups with Wave 2)
  - Message: `refactor: upgrade error handling to do/catch with os.Logger and add tests`
  - Files: `Sources/FileStash/StashStore.swift`, `Tests/FileStashTests/StashStoreTests.swift`
  - Pre-commit: `swift build && swift test`

- [x] 7. TDD — finalizeDrag polling replacement

  **What to do**:
  - RED: Write tests that verify:
    - `finalizeDrag(item:)` detects when a file has been moved out of stash (file no longer exists)
    - `finalizeDrag(item:)` restores a file to its original location when it still exists in stash after drag
    - `finalizeDrag(item:)` handles the case where the original directory no longer exists (creates directory or falls back)
    - `finalizeDrag(item:)` times out after 2 seconds if file state is uncertain
  - GREEN: Replace the `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` in `finalizeDrag` with a polling mechanism:
    - Poll every 0.05 seconds to check if file still exists in stash
    - Maximum timeout of 2 seconds
    - If file disappears (successful drag out): update metadata, refresh items
    - If file remains after timeout: attempt restore to original location
    - If original directory doesn't exist: create it, or fall back to Desktop
  - REFACTOR: Clean up any redundant polling logic

  **Must NOT do**:
  - Don't use `NSFileCoordinator` (it coordinates access, not completion)
  - Don't change the public API of `finalizeDrag`
  - Don't add DispatchSourceFileSystemObject here (that's Task 13)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Core behavior change with TDD, needs careful test-design
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (parallel with Task 6)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `Sources/FileStash/StashStore.swift:103-131` — Current `finalizeDrag` with 0.3s fixed delay
  - Metis finding: "NSFileCoordinator coordinates access between processes, not drag completion. Use polling instead."
  - `Sources/FileStash/StashStore.swift:161-173` — `uniqueURL(at:for:)` helper for collision-safe naming

  **Acceptance Criteria**:
  - [ ] No `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` in `finalizeDrag`
  - [ ] Polling mechanism checks every 0.05s with 2s timeout
  - [ ] Handles original directory not existing (creates directory or falls back)
  - [ ] `swift test` passes with all finalizeDrag tests GREEN

  **QA Scenarios**:

  ```
  Scenario: finalizeDrag uses polling instead of fixed delay
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `grep -c "asyncAfter" Sources/FileStash/StashStore.swift` → count is 0 (or only in other contexts)
      2. `swift test` → all finalizeDrag tests pass
      3. Verify polling constant exists (0.05s interval, 2s timeout)
    Expected Result: No 0.3s asyncAfter in finalizeDrag, polling mechanism in place
    Failure Indicators: asyncAfter still present, tests fail
    Evidence: .sisyphus/evidence/task-7-finalize-polling.txt

  Scenario: Original directory missing fallback
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift test` → tests verify behavior when original directory doesn't exist
      2. Verify code handles missing directory (creates it or falls back)
    Expected Result: Tests cover directory-missing case
    Failure Indicators: No test for this case, or test fails
    Evidence: .sisyphus/evidence/task-7-directory-fallback.txt
  ```

  **Commit**: YES (groups with Wave 2)
  - Message: `fix: replace finalizeDrag fixed delay with polling mechanism`
  - Files: `Sources/FileStash/StashStore.swift`, `Tests/FileStashTests/StashStoreTests.swift`
  - Pre-commit: `swift build && swift test`

- [x] 8. TDD — uniqueURL dedup + edge cases

  **What to do**:
  - RED: Write tests for:
    - `uniqueDestinationURL` produces "file 2.txt" when "file.txt" exists
    - `uniqueURL` produces "file 2.txt" when "file.txt" exists at destination
    - Both methods handle files without extensions ("filename" → "filename 2")
    - Stashing a file that's already in the stash directory is rejected (edge case E4)
  - GREEN: Extract shared implementation from `uniqueDestinationURL(for:)` and `uniqueURL(at:for:)` into a single private method `uniqueFilename(at:baseName:extension:)`
  - Add a guard at the top of `stash(url:)` to reject files already inside the stash directory
  - REFACTOR: Update all callers to use the shared method

  **Must NOT do**:
  - Don't over-abstract (no generic filename utility class)
  - Don't change the collision naming format ("name 2.ext")

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple changes with edge cases, but not architecturally complex
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (parallel with Tasks 6, 7)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 4

  **References**:
  - `Sources/FileStash/StashStore.swift:147-158` — `uniqueDestinationURL(for:)`
  - `Sources/FileStash/StashStore.swift:161-173` — `uniqueURL(at:for:)`
  - `Sources/FileStash/StashStore.swift:75-101` — `stash(url:)` where the self-stash guard should be added
  - Metis finding E4: "file dragged from stash back to stash creates duplicate"

  **Acceptance Criteria**:
  - [ ] `uniqueDestinationURL` and `uniqueURL` share one implementation
  - [ ] `stash(url:)` rejects files already in the stash directory
  - [ ] `swift test` passes with uniqueURL tests GREEN
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: URL deduplication works correctly
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift test` → all uniqueURL tests pass
      2. `grep -c "func unique" Sources/FileStash/StashStore.swift` → count is 1 (shared) or 2 (one calling shared)
      3. Verify self-stash guard exists in stash(url:)
    Expected Result: One shared implementation, self-stash rejection, all tests pass
    Failure Indicators: Duplicate implementations remain, no self-stash guard
    Evidence: .sisyphus/evidence/task-8-url-dedup.txt
  ```

  **Commit**: YES (groups with Wave 2)
  - Message: `refactor: deduplicate uniqueURL methods and prevent self-stashing`
  - Files: `Sources/FileStash/StashStore.swift`, `Tests/FileStashTests/StashStoreTests.swift`
  - Pre-commit: `swift build && swift test`

- [x] 9. Icon caching in StashStore

  **What to do**:
  - Add a private `iconCache: [String: NSImage]` dictionary to `StashStore`
  - In `refreshItems()`, check `iconCache` before calling `NSWorkspace.shared.icon(forFile:)`
  - Only load icons for files not already in cache
  - Invalidate cache entries for files that no longer exist in the stash
  - The cache key should be the file path (matching the new stable `StashItem.id`)

  **Must NOT do**:
  - Don't implement LRU eviction or memory pressure handling
  - Don't add cache size limits
  - Don't make the cache thread-safe (StashStore is @MainActor)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple dictionary cache, 10-15 lines of code
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (parallel with Tasks 6-8)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `Sources/FileStash/StashStore.swift:54-73` — Current `refreshItems()` that reloads all icons every time
  - Line 66-67: `NSWorkspace.shared.icon(forFile: url.path)` and `icon.size = NSSize(width: 48, height: 48)` — repeated on every refresh

  **Acceptance Criteria**:
  - [ ] `StashStore` has an `iconCache` dictionary
  - [ ] `refreshItems()` uses cached icons when available
  - [ ] Stale cache entries (files no longer in stash) are removed
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: Icon cache prevents redundant lookups
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. Verify `iconCache` dictionary exists in StashStore
      2. Verify `refreshItems()` checks cache before calling NSWorkspace.shared.icon
      3. `swift build` → exit 0
    Expected Result: Cache dictionary present, used in refreshItems, build succeeds
    Failure Indicators: No cache, direct icon call on every refresh
    Evidence: .sisyphus/evidence/task-9-icon-cache.txt
  ```

  **Commit**: YES (groups with Wave 2)
  - Message: `perf: add icon caching to StashStore for faster refreshes`
  - Files: `Sources/FileStash/StashStore.swift`
  - Pre-commit: `swift build`

- [x] 10. Extract magic numbers to constants

  **What to do**:
  - In `StashWindowManager.swift`:
    - Extract `300` (width), `420` (height) → `panelWidth`, `panelHeight`
    - Extract `20` (offset) → `panelOffset`
    - Extract `150` → `(panelWidth / 2)` (derived from panelWidth)
  - In `DragDetector.swift`:
    - Already has named constants (`dragThreshold`, `maxDetectionInterval`, `trackingInterval`) — verify these are good, don't change
  - In `DraggableFileItem.swift`:
    - Extract `10` (cornerRadius) → `itemCornerRadius`
    - Extract `8` (image top padding), `4` (label padding) → named constants
    - Extract `40` (icon size), `11` (font size) → named constants
  - In `StashContentView.swift`:
    - Extract `16` (icon size) for the close button area

  **Must NOT do**:
  - Don't change any actual values — only extract to named constants
  - Don't create a separate constants file (keep constants near their usage)
  - Don't change DragDetector's already-named constants

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Extracting magic numbers to named constants, no logic changes
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6-9)
  - **Blocks**: None
  - **Blocked By**: Task 1

  **References**:
  - `Sources/FileStash/StashWindowManager.swift:16,19,30-31` — `150`, `430` (panel width/2 hint, height reference), `20` offset
  - `Sources/FileStash/DragOut/DraggableFileItem.swift:40,43,52-68` — corner radius, paddings, icon size
  - `Sources/FileStash/Views/StashContentView.swift:38-42` — close button dimensions

  **Acceptance Criteria**:
  - [ ] All numeric literals in StashWindowManager related to layout are named constants
  - [ ] All numeric literals in DraggableFileItem related to layout are named constants
  - [ ] `swift build` succeeds with no behavior change

  **QA Scenarios**:

  ```
  Scenario: Magic numbers extracted to constants
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift build` → exit 0
      2. Verify StashWindowManager.swift has named constants for panel dimensions
      3. Verify DraggableFileItem.swift has named constants for layout values
    Expected Result: Named constants replace magic numbers, build succeeds
    Failure Indicators: Magic numbers still present, build failure
    Evidence: .sisyphus/evidence/task-10-magic-numbers.txt
  ```

  **Commit**: YES (groups with Wave 2)
  - Message: `refactor: extract magic numbers to named constants`
  - Files: `Sources/FileStash/StashWindowManager.swift`, `Sources/FileStash/DragOut/DraggableFileItem.swift`, `Sources/FileStash/Views/StashContentView.swift`
  - Pre-commit: `swift build`

- [x] 11. FileSystemProvider protocol + mock implementation

  **What to do**:
  - RED: Write tests that use a `MockFileSystemProvider` to verify `StashStore` behavior without touching real files
  - GREEN: Create `FileSystemProvider` protocol in `Sources/FileStash/Services/FileSystemProvider.swift`:
    ```swift
    protocol FileSystemProvider: Sendable {
        func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
        func contentsOfDirectory(at url: URL, includingPropertiesForKeys: [URLResourceKey]?) throws -> [URL]
        func moveItem(at from: URL, to to: URL) throws
        func copyItem(at from: URL, to to: URL) throws
        func removeItem(at: URL) throws
        func fileExists(atPath path: String) -> Bool
        func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    }
    ```
  - Create `MockFileSystemProvider` in `Tests/FileStashTests/Mocks/`
  - Refactor `StashStore` to accept `FileSystemProvider` as initializer parameter (defaulting to `FileManager.default` for production)
  - REFACTOR: Update AppDelegate to pass real `FileManager.default` when creating StashStore

  **Must NOT do**:
  - Don't create protocols for `DragDetector` or `StashWindowManager` (only StashStore needs mocking for tests)
  - Don't change any runtime behavior — this is purely structural
  - Don't add more protocols than `FileSystemProvider`

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Protocol design + mock implementation + StashStore refactoring + test updates
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 12
  - **Blocked By**: Tasks 6, 7

  **References**:
  - `Sources/FileStash/StashStore.swift` — All FileManager usages that need abstraction
  - Lines 22-25: `FileManager.default.urls` for stashDirectory
  - Lines 36-38: `FileManager.default.createDirectory`
  - Lines 55: `FileManager.default.contentsOfDirectory`
  - Lines 81-88: `FileManager.default.moveItem`, `copyItem`, `removeItem`
  - Lines 109: `FileManager.default.fileExists`
  - Lines 117: `FileManager.default.moveItem` in finalizeDrag
  - Metis guardrail: "Only create protocols where tests need mocks. Target: only StashStore's file system access needs a protocol."

  **Acceptance Criteria**:
  - [ ] `FileSystemProvider` protocol exists with all necessary FileManager operations
  - [ ] `MockFileSystemProvider` exists in test target
  - [ ] `StashStore` accepts `FileSystemProvider` via init (with default)
  - [ ] All existing StashStore tests pass with mock provider
  - [ ] No `.shared` singleton pattern for StashStore creation in production code (AppDelegate creates and injects)
  - [ ] `swift build && swift test` → both pass

  **QA Scenarios**:

  ```
  Scenario: DI refactoring enables mock testing
    Tool: Bash
    Preconditions: Project builds and tests pass
    Steps:
      1. `swift build` → exit 0
      2. `swift test` → all tests pass
      3. `grep -c "FileSystemProvider" Sources/FileStash/Services/FileSystemProvider.swift` → count > 0
      4. `grep -c "MockFileSystemProvider" Tests/FileStashTests/Mocks/` → file exists
      5. `grep "StashStore.shared" Sources/FileStash/AppDelegate.swift` → AppDelegate creates StashStore explicitly
    Expected Result: Protocol exists, mock exists, all tests pass, AppDelegate wires dependencies
    Failure Indicators: Protocol not found, mock not found, tests fail, .shared still used in production paths
    Evidence: .sisyphus/evidence/task-11-di-protocol.txt
  ```

  **Commit**: YES (groups with Wave 3)
  - Message: `refactor: introduce FileSystemProvider protocol for dependency injection`
  - Files: `Sources/FileStash/Services/FileSystemProvider.swift`, `Sources/FileStash/StashStore.swift`, `Sources/FileStash/AppDelegate.swift`, `Tests/FileStashTests/Mocks/MockFileSystemProvider.swift`, `Tests/FileStashTests/StashStoreTests.swift`
  - Pre-commit: `swift build && swift test`

 - [x] 12. Inject StashStore through DI, remove .shared from production code paths

  **What to do**:
  - Change `AppDelegate` to own the `StashStore` instance and inject it into `StashWindowManager`
  - Change `StashWindowManager` to accept `StashStore` via init instead of accessing `.shared`
  - Change `DropZoneNSView` to accept `StashStore` (or its protocol) instead of accessing `.shared`
  - Change `DraggableFileItemView` to accept `StashItem`'s store reference instead of accessing `.shared`
  - Keep `StashStore.shared` as a convenience for SwiftUI `.environmentObject` injection, but production code should use injected instances
  - The `.shared` static should still exist for SwiftUI's `@EnvironmentObject` pattern, but init-based injection should be the primary path

  **Must NOT do**:
  - Don't remove `.shared` entirely (SwiftUI `.environmentObject` still needs it)
  - Don't create protocols for `StashWindowManager` or `DragDetector`
  - Don't change any runtime behavior

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multi-file refactoring touching several components
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 11

  **References**:
  - `Sources/FileStash/AppDelegate.swift` — Creates and wires up components
  - `Sources/FileStash/StashWindowManager.swift:63` — Uses `StashStore.shared` via `.environmentObject`
  - `Sources/FileStash/Views/DropZoneView.swift:28` — `StashStore.shared.stash(url:)`
  - `Sources/FileStash/DragOut/DraggableFileItem.swift:113` — `StashStore.shared.finalizeDrag(item:)`
  - `Sources/FileStash/StashContentView.swift:4` — `@EnvironmentObject var store: StashStore`

  **Acceptance Criteria**:
  - [ ] `AppDelegate` creates `StashStore` instance and passes it to `StashWindowManager`
  - [ ] `StashWindowManager` receives `StashStore` via init parameter
  - [ ] `DropZoneNSView` receives `StashStore` reference instead of `.shared`
  - [ ] `DraggableFileItemView` receives `StashStore` reference instead of `.shared`
  - [ ] SwiftUI views still use `@EnvironmentObject` (this is fine)
  - [ ] `swift build && swift test` → both pass

  **QA Scenarios**:

  ```
  Scenario: DI removes .shared from production code paths
    Tool: Bash
    Preconditions: Project builds and tests pass
    Steps:
      1. `swift build && swift test` → both pass
      2. `grep -n "StashStore.shared" Sources/FileStash/StashWindowManager.swift` → only in SwiftUI environmentObject setup, not in direct method calls
      3. `grep -n "StashStore.shared" Sources/FileStash/Views/DropZoneView.swift` → returns nothing
      4. `grep -n "StashStore.shared" Sources/FileStash/DragOut/DraggableFileItem.swift` → returns nothing
    Expected Result: .shared only used for SwiftUI environment injection, not direct access
    Failure Indicators: .shared used in DropZoneView or DraggableFileItem
    Evidence: .sisyphus/evidence/task-12-di-injection.txt
  ```

  **Commit**: YES (groups with Wave 3)
  - Message: `refactor: inject StashStore through DI instead of .shared`
  - Files: `Sources/FileStash/AppDelegate.swift`, `Sources/FileStash/StashWindowManager.swift`, `Sources/FileStash/Views/DropZoneView.swift`, `Sources/FileStash/DragOut/DraggableFileItem.swift`
  - Pre-commit: `swift build && swift test`

- [x] 13. DispatchSourceFileSystemObject file watching

  **What to do**:
  - Add a `DispatchSourceFileSystemObject` watcher in `StashStore` that monitors the stash directory
  - When files are added/removed from the stash directory externally (e.g., via Finder), trigger `refreshItems()`
  - Use a simple 0.5s coalescing timer to debounce rapid successive changes
  - Start watching in `init()`, stop in `deinit`
  - The watcher should handle: file creation, deletion, rename, and metadata changes

  **Must NOT do**:
  - Don't watch for external metadata changes (only file additions/deletions in the stash directory)
  - Don't add debounce complexity beyond a simple 0.5s timer
  - Don't use `FSEvents` (overkill for a single directory)
  - Don't add any UI for enabling/disabling file watching

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: AppKit file watching with careful lifecycle management
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 11, 12)
  - **Blocks**: None
  - **Blocked By**: Tasks 2, 9

  **References**:
  - `Sources/FileStash/StashStore.swift` — Where the file watcher should be added
  - `DispatchSourceFileSystemObject` Apple docs — API for watching file system changes
  - `makeFileSystemObjectEventSource` — The specific API to create the watcher
  - Watch flags: `.write`, `.delete`, `.rename`, `.attrib` — minimum needed

  **Acceptance Criteria**:
  - [ ] `StashStore` creates a `DispatchSourceFileSystemObject` for the stash directory
  - [ ] External file additions/deletions trigger `refreshItems()` within 1 second
  - [ ] A 0.5s coalescing timer debounces rapid changes
  - [ ] Watcher is properly started in `init()` and cancelled in `deinit`
  - [ ] `swift build` succeeds

  **QA Scenarios**:

  ```
  Scenario: File watching triggers refresh
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift build` → exit 0
      2. `grep -c "DispatchSource" Sources/FileStash/StashStore.swift` → count > 0
      3. `grep -c "makeFileSystemObjectEventSource" Sources/FileStash/StashStore.swift` → count > 0
      4. Verify debounce timer exists (0.5s)
    Expected Result: File watcher implemented with DispatchSource and debounce
    Failure Indicators: No DispatchSource, no debounce, build failure
    Evidence: .sisyphus/evidence/task-13-file-watching.txt
  ```

  **Commit**: YES (groups with Wave 3)
  - Message: `feat: add file system watching for stash directory auto-refresh`
  - Files: `Sources/FileStash/StashStore.swift`
  - Pre-commit: `swift build`

- [ ] 14. NSLocalizedString infrastructure + string migration

  **What to do**:
  - Create `Sources/FileStash/en.lproj/Localizable.strings` with English translations
  - Create `Sources/FileStash/zh-Hans.lproj/Localizable.strings` with Chinese originals
  - Migrate all hardcoded Chinese strings in the codebase:
    - `AppDelegate.swift`: "显示/隐藏", "打开暂存文件夹", "退出"
    - `StashContentView.swift`: "拖拽文件到这里"
    - Any other user-facing strings
  - Replace each hardcoded string with `NSLocalizedString("key", comment: "description")`
  - Add the `.lproj` directories to Xcode project or ensure they're accessible via SPM
  - Register the localizations in `Info.plist` (en, zh-Hans)

  **Must NOT do**:
  - Don't add `.stringsdict` for plural handling
  - Don't add a language switching UI
  - Don't add RTL support
  - Don't reword the existing Chinese text — keep it exactly the same
  - Don't add strings that don't already exist in the codebase

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multi-file changes + .strings file management + Package.swift resource configuration
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: Task 12

  **References**:
  - `Sources/FileStash/AppDelegate.swift:45-49` — Hardcoded Chinese menu items
  - `Sources/FileStash/Views/StashContentView.swift:71` — "拖拽文件到这里"
  - Apple `NSLocalizedString` docs: `NSLocalizedString("key", tableName: nil, bundle: .main, value: "", comment: "description")`
  - SPM resource configuration: `Package.swift` needs `.resources` rule for `.lproj` directories

  **Acceptance Criteria**:
  - [ ] `en.lproj/Localizable.strings` exists with English translations
  - [ ] `zh-Hans.lproj/Localizable.strings` exists with Chinese originals
  - [ ] No hardcoded user-facing Chinese strings remain in Swift files (search for common Chinese characters)
  - [ ] `Package.swift` includes `.resources` for `.lproj` directories
  - [ ] `build_app.sh` includes localization files in `.app` bundle
  - [ ] `swift build` succeeds
  - [ ] `swift test` passes

  **QA Scenarios**:

  ```
  Scenario: All Chinese strings migrated to NSLocalizedString
    Tool: Bash
    Preconditions: Project builds
    Steps:
      1. `swift build` → exit 0
      2. `grep -rn "NSLocalizedString" Sources/FileStash/` → multiple matches
      3. `ls Sources/FileStash/en.lproj/Localizable.strings` → file exists
      4. `ls Sources/FileStash/zh-Hans.lproj/Localizable.strings` → file exists
      5. Search for remaining hardcoded Chinese in Swift files: `grep -Pn '[\x{4e00}-\x{9fff}]' Sources/FileStash/*.swift Sources/FileStash/**/*.swift` → should find none (or only in comments/localization setup)
    Expected Result: All Chinese strings use NSLocalizedString, .lproj files exist
    Failure Indicators: Hardcoded Chinese still in Swift files, .lproj missing
    Evidence: .sisyphus/evidence/task-14-localization.txt
  ```

  **Commit**: YES (groups with Wave 4)
  - Message: `feat: add NSLocalizedString support and migrate all Chinese strings`
  - Files: `Sources/FileStash/en.lproj/Localizable.strings`, `Sources/FileStash/zh-Hans.lproj/Localizable.strings`, `Sources/FileStash/AppDelegate.swift`, `Sources/FileStash/Views/StashContentView.swift`, `Package.swift`, `build_app.sh`
  - Pre-commit: `swift build && swift test`

- [ ] 15. Fix Bundle ID + .gitignore + git init

  **What to do**:
  - Change `BUNDLE_ID="com.yourname.FileStash"` in `build_app.sh` to a real identifier (e.g., `com.ray.FileStash` or ask user)
  - Ensure `.gitignore` covers: `.build/`, `*.xcodeproj/`, `*.xcworkspace/`, `FileStash.app/`, `DerivedData/`, `.DS_Store`, `*.swp`
  - Run `git init` and make an initial commit
  - Verify `swift build`, `swift test`, and `./build_app.sh` all still work

  **Must NOT do**:
  - Don't push to any remote
  - Don't create a GitHub repo
  - Don't add any CI configuration

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file changes + git init
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 14)
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `build_app.sh:6` — `BUNDLE_ID="com.yourname.FileStash"` placeholder
  - AGENTS.md → "Not a git repo — needs `git init` before any git operations"

  **Acceptance Criteria**:
  - [ ] `build_app.sh` has a real bundle identifier (not `com.yourname`)
  - [ ] `.gitignore` exists with standard entries
  - [ ] `git status` shows initialized repo
  - [ ] `swift build && swift test && ./build_app.sh` all succeed
  - [ ] Initial commit created

  **QA Scenarios**:

  ```
  Scenario: Git initialized and Bundle ID fixed
    Tool: Bash
    Preconditions: None
    Steps:
      1. `git status` → shows initialized repo
      2. `grep "BUNDLE_ID" build_app.sh` → no longer contains "com.yourname"
      3. `cat .gitignore` → contains .build, .DS_Store, etc.
      4. `swift build && swift test` → both pass
      5. `./build_app.sh` → FileStash.app created
    Expected Result: Git repo initialized, Bundle ID fixed, all builds pass
    Failure Indicators: Git not initialized, placeholder Bundle ID remains, build failures
    Evidence: .sisyphus/evidence/task-15-bundle-git.txt
  ```

  **Commit**: YES (groups with Wave 4)
  - Message: `chore: fix Bundle ID, add .gitignore, initialize git repo`
  - Files: `build_app.sh`, `.gitignore`
  - Pre-commit: `swift build && swift test && ./build_app.sh`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `swift build` + `swift test`. Review all changed files for: force unwraps (!), empty catches, print() in prod (should be Logger), commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names. Verify no protocols exist for types that don't need mocking (only StashStore's file system should have a protocol).
  Output: `Build [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state (`swift build -c release && ./build_app.sh`). Launch FileStash.app. Test: (1) Drag file from Finder → file appears in panel, (2) Drag file out → file restores to original location, (3) Drag same file again → collision-safe naming, (4) Right-click menu items work, (5) Panel drag handle moves window. Save screenshots.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 1**: `refactor: fix critical bugs and add test target` — StashItem identity, atomic metadata, dead code removal, path fix
- **Wave 2**: `refactor: TDD core logic improvements` — error handling, polling, dedup, icon cache, constants
- **Wave 3**: `refactor: dependency injection and file watching` — FileSystemProvider protocol, DI wiring, DispatchSource
- **Wave 4**: `feat: localization and project polish` — NSLocalizedString, Bundle ID, .gitignore

---

## Success Criteria

### Verification Commands
```bash
swift build                    # Expected: Build complete
swift test                     # Expected: All tests pass
swift build -c release         # Expected: Build complete
./build_app.sh                 # Expected: FileStash.app created
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] No `try?` remaining in StashStore.swift
- [ ] No `.shared` access in production code paths (except AppDelegate setup)
- [ ] No hardcoded Chinese strings in Swift code (all via NSLocalizedString)
- [ ] No force unwraps on FileManager URLs
- [ ] No duplicate uniqueURL logic
- [ ] Bundle ID not a placeholder