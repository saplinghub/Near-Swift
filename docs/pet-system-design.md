# 桌宠系统成熟化设计文档

> 基于 GitHub 上成熟实现（OpenAI Codex Pet 生态、OpenPets / OpenPetsKit）的调研结论，针对本项目（Near-Swift / NearCountdown）桌宠子系统提出的一套可落地的演进设计。
>
> 状态：**设计稿 v1（待评审）** · 关联代码：`Models/PetModel.swift`、`Services/PetManager.swift`、`Views/PetWindow.swift`、`Views/BubbleWindow.swift`、`Views/LottieView.swift`、`Services/NotificationManager.swift`

---

## 0. TL;DR

本项目桌宠已有不错的骨架（状态机雏形、气泡交互、贴边吸附、系统感知），但存在四类结构性问题：

| # | 问题 | 后果 |
|---|------|------|
| P1 | 状态分散在 `PetManager` / `PetModel` / `PetWindow` / `BubbleWindow`，靠 0.5s 轮询与多路 `sink` 互相纠正 | 心智负担高，易出现“状态打架”，靠自检兜底 |
| P2 | 动画只有单一 Lottie（`guaishou`）+ 代码内 if/else，无“多语义动画”资源契约 | 无法复用社区宠物资产，动画与业务状态强耦合 |
| P3 | 没有“外部输入层”（命令模型 + 本地通道），只有内置代码能驱动宠物 | AI Agent / 脚本 / 其它 App 无法让宠物说话 |
| P4 | 气泡是“单条消息”，新消息直接顶掉旧的 | 无法表达多任务并发状态（构建/评审/完成…） |

设计目标（按性价比排序，可分阶段落地）：

1. **统一状态机**：所有动画 / 拖拽 / 行走 / 气泡 / 贴边状态收敛到一个 `PetDirector`（单一宿主），渲染层只消费快照。
2. **引入雪碧图动画契约**：支持 “行 = 语义动画、列 = 帧、帧时长可配” 的 `SpriteAtlas` 渲染器（对齐 Codex Pet / OpenPets 的 8×9 契约），与 Lottie 并存。
3. **定义命令模型 + 本地 IPC（socket / MCP）**：让 `notify / playAnimation / stopAnimation` 可被任何本地进程调用。
4. **气泡线程化（threadId）**：同一任务可原地更新，支持多任务堆叠。

> 不做的（避免过度设计）：不做插件运行时 / 沙箱子进程、不做跨设备同步、不引入新第三方框架。

---

## 1. 调研结论摘要

### 1.1 Codex Pet 生态（资源契约标准）

- 固定雪碧图：`1536×1872`，8 列 × 9 行，格 `192×208`，透明底。
- 行 = 语义状态：`idle / running-right / running-left / waving / jumping / failed / waiting / running / review`。
- 每帧时长可配（如 idle `[280,110,110,140,140,320]ms`）。
- 包结构：`~/.codex/pets/<id>/pet.json + spritesheet.webp`，社区画廊（awesome-codex-pet，858★）提供 230+ 可安装宠物，一键安装到本地。

### 1.2 OpenPets / OpenPetsKit（架构参照）

- **单一渲染宿主** `OpenPetsHost`：持有 `NSPanel`，内部集中管理 `currentAnimation / currentFrameIndex / Timer 帧调度`。
- **纯值命令模型** `PetCommand`：`notify / playAnimation / stopAnimation / clearMessage / ping / shutdown`，通过 **Unix socket + MCP/CLI** 输入 → 任何 agent / 脚本 / App 都能驱动同一只宠物。
- **通知 = 状态**：`notify` 携带 `status(running/review/done/failed/waiting/message)` + `threadId`（可原地更新同一气泡）。
- **动画调度细节**：
  - `scheduleNextFrame()`：每帧按**该帧专属时长**起一次性 Timer（非固定 tick）。
  - `entryFrame(for:)`：切换动画时从**语义入口帧**进入（waving/jumping 从第 1 帧）。
  - 动画可**抢占**：新动画先取消旧动画及其 TTL；非 idle 动画带 `ttlSeconds`，到点自动 `resumeAmbientAnimation()`（回 idle）。
  - 拖拽甩出 → **投掷物理** `PetLaunchMotion`：速度阈值 650 触发滑行、指数衰减(rate 3.8)、碰屏边速度清零、低于阈值停下；`running-left/right` 由 `velocity.dx` 符号决定。
  - 屏幕布局变化（拔插显示器）→ 自动 `callPet()` 把宠物唤回可视区。
- **Surface 插件模型**：宠物旁挂“宿主拥有的云朵热点”（电量、配额环），插件只上报语义值，不控制渲染/定位。

---

## 2. 现状分析（Near-Swift）

### 2.1 现有资产（值得保留）

- **通知中心**：`NotificationManager.shared.post(NearNotification)` 已实现优先级打断（`NearNotificationType.priority`），`NearNotification` 带 `actions`（气泡按钮）。
- **拟人化文案系统**：`PetManager` 内置大量古风台词、`randomQuotes / dockQuotes / undockQuotes` 等，价值高。
- **贴边 dock / 吸附**：`handleDocking` + `getOptimalDockEdge` + `autoSnapToEdge` 已较完整（含 dock/undock 台词）。
- **拖拽 & 行走**：`PetWindow.mouseUp → PetManager.finishDragging()`；行走用 `NSAnimationContext` 缓动（非 Timer 步进），方向翻转 `model.facingDirection`。
- **消息气泡**：`BubbleWindow` 按文本高度手动重算（`calculateBubbleHeight`），支持按钮动作，尖角样式。
- **系统感知**：CPU 负载 → 台词（`updateSystemAwareness`）、健康提醒、天气感知（分层调度 30s / 60s）。
- **闲置抑制**：`PowerStateManager` 提供 isIdle，进入 idle 停掉全部 timer 与监控（省电）。

### 2.2 结构性问题（本次要解决的）

**P1 状态分散 + 轮询纠正**：
- 拖拽状态 `isDragging` 同时存在于 `PetManager`（私有）与 `PetModel`（@Published），靠 0.5s Timer + `NSEvent.pressedMouseButtons` 物理兜底纠正（`setupPowerObservation` 中）。这属于“状态不同步后的补偿”，说明事件链路不可靠（AppKit 漏 mouseUp）。
- `refreshAnimationState(reason:)` 被多方调用，`PetAnimationResolver.resolve(model:)` 每次从一堆分散布尔值里推导动画，扩展新状态困难。

**P2 单一动画源**：
- `PetContentView` 固定渲染 `LottieView(animationName: "guaishou")`，`PetAnimationDescriptor` 里 `animationName` 永远同一值。
- 动画意图被压成 `playback(playing/stopped) + bob + facing` 三个开关，丢失“哪个动画、第几帧、循环几次”等表达力。

**P3 无外部输入**：
- 只有 `PetManager.notify/saySomething` 这类内部方法，无进程外调用能力。

**P4 气泡单条互顶**：
- `saySomething` 里若 `isMessageVisible` 则把旧消息存入 `oldMessage` 后顶替。做不了“构建中… → 构建完成”的原地更新。

**P5（次要）位置持久化缺失**：宠物没有记忆上次位置（OpenPets 有 `positions.json`），每次启动回到屏幕中央。

---

## 3. 目标架构

```
┌──────────────────────────── 进程边界（单进程，本地） ───────────────────────────┐
│                                                                                │
│  ┌──────────────┐    ┌──────────────────────┐    ┌──────────────────────────┐  │
│  │  输入层       │    │  核心：PetDirector     │    │  渲染层                   │  │
│  │              │    │  (单一状态机宿主)       │    │                          │  │
│  │ PetCommand   │───▶│                      │───▶│  SpriteAtlasView / Lottie │  │
│  │ (值模型)      │    │  animationStateMachine│    │  PetContentView           │  │
│  │              │    │  motion / docking     │    │  BubbleStack (threadId)   │  │
│  │ IPC 适配器:   │    │  bubbles: [threadId]  │    │                          │  │
│  │  local socket│    │  ambientScheduler     │    └──────────────────────────┘  │
│  │  / MCP / CLI │    │                      │                                 │
│  └──────────────┘    └──────────────────────┘                                 │
│                                                                                │
│  现有能力继续作为“输入源”：NotificationManager / 系统监控 / 健康提醒 / 天气      │
└────────────────────────────────────────────────────────────────────────────────┘
```

**关键原则**：
1. **命令进、状态机算、渲染只看快照**：所有外部与内部事件统一转成 `PetCommand`（或等价事件），由 `PetDirector` 决定状态；View 永远不直接改状态。
2. **资源契约与渲染器解耦**：宠物形象 = 一个 `PetBundle`（Lottie JSON 或雪碧图 2 选 1），业务状态只表达“语义动画”，不关心美术格式。
3. **动画 = 抢占式 + TTL 回闲**：任何非 idle 动画都可被更高语义打断，且带 TTL；到点回到 idle / 任务态。
4. **可测**：`PetDirector` 不依赖 AppKit 窗口（窗口注入为协议 `PetSurface`），逻辑可用 XCTest 单测。

---

## 4. 模块设计

### 4.1 状态模型（PetModel 重构方向）

建议保留 `PetModel` 作为“对外发布的 @Published 快照”，但**收紧写权限**：只有 `PetDirector` 能写；视图只读。

```
PetModel (ObservableObject)
├── identity:   enabled / visible / opacity / docked(edge)
├── motion:     position(CGPoint) / facing(left/right)
├── activity:   idle | walking | interacting | docked      // 保留现有 PetState 语义
├── animation:  current(AnimSemantic) / isSpeaking / playback  // 由 Director 维护
└── bubbles:    [BubbleItem]   // 多线程气泡（见 4.5）
```

新增语义枚举（对齐生态，逐步替换 `PetAnimationState` 的魔法字符串）：

```swift
enum PetAnimSemantic: Equatable {
    case idle
    case walking(direction: PetFacingDirection)
    case dragging
    case speaking
    case waiting          // 任务等待
    case working          // 任务进行中（构建/运行）
    case review           // 需要评审
    case success          // 完成
    case failure          // 失败
    case docked
    case lowPower
}
```

> 为什么用语义而非直接映射动画文件：语义由业务产生（“倒计时到点=success”），渲染层负责把语义翻译成 Lottie 或雪碧图行。这样换皮肤/换格式不动业务代码。

### 4.2 核心宿主 PetDirector（取代/收敛 PetManager 的状态职责）

```swift
@MainActor
final class PetDirector {
    // 渲染宿主（协议化，便于测试）
    protocol PetSurface {
        var frame: NSRect { get set }          // 窗口位置/尺寸
        var isVisible: Bool { get set }
        func present(snapshot: PetRenderSnapshot) // 把当前帧交给视图
    }

    // 输入（命令）——所有入口统一走这里
    func handle(_ command: PetCommand)

    // 内部驱动
    private var animState: AnimStateMachine      // 见 4.3
    private var motionController: MotionController // 见 4.4
    private var bubbleController: BubbleController // 见 4.5
    private var ambientScheduler: AmbientScheduler // 见 4.6
}
```

**迁移策略（关键！）**：不是推翻重写，而是**先把现有 `PetManager` 里的状态写入收口**：
- 保留 `PetManager` 现有的通知/监控/文案逻辑（它是很好的“输入源”）。
- 新增 `PetDirector` 承担“状态机 + 渲染推进”，`PetManager` 改为调用 `director.handle(...)` 并监听输出。
- 分两步：step1 双写校验（新旧并行，只读对比），step2 切换。

`PetCommand`（值模型，可 Codable → 天然支持 IPC）：

```swift
enum PetCommand: Codable, Equatable {
    case show
    case hide
    case speak(text: String, kind: SpeakKind)          // kind: 拟人/系统/健康/天气/倒计时…
    case updateBubble(BubbleUpdate)                     // threadId 原地更新
    case playAnimation(PetAnimSemantic, ttl: TimeInterval?)
    case stopAnimation
    case walkTo(target: CGPoint)                        // 供测试 / 外部遥控
    case dock
    case undock
    case setPosition(CGPoint)
    case ping
}
```

### 4.3 动画状态机 AnimStateMachine

对齐 OpenPets `scheduleNextFrame` + `entryFrame` + TTL 回闲。

```swift
struct AnimationClip {            // 一“段”动画
    let semantic: PetAnimSemantic
    let frames: [CGImage]         // 或 Lottie 引用 + 时长
    let frameDurationsMS: [Int]
    let loop: Bool                // true=循环；false=播 N 次后回 ambient
    let ttl: TimeInterval?        // 到点强制回 ambient
}

@MainActor
final class AnimStateMachine {
    private(set) var current: AnimationClip?
    private var frameIndex: Int = 0
    private var frameTimer: Timer?

    func play(_ clip: AnimationClip, reason: String)  // 抢占
    func stopAndReturnToAmbient(reason: String)
    func tick()   // 由 frameTimer 驱动：按当前帧时长调度下一帧
}
```

要点：
- **entry frame**：每种语义定义入口帧（如 speaking 从第 1 帧），避免从 0 生硬切换。
- **ambient**：idle / docked 视为 ambient；任何短动画播完 / TTL 到 → `stopAndReturnToAmbient`。
- **帧时长表**：来自资源包 manifest，非固定 tick —— 这是“质感”关键。

### 4.4 运动控制器 MotionController（拖拽投掷 + 行走 + dock + 屏幕变化恢复）

把 `PetManager` 现有散落的 `handleDocking / pushBackToVisible / autoSnapToEdge / startRandomWalk` 归拢，并补上生态验证过的物理：

```swift
@MainActor
final class MotionController {
    struct LaunchConfig {
        var launchSpeedThreshold: CGFloat = 650   // 甩出即滑行
        var stopSpeedThreshold: CGFloat = 45
        var decelerationRate: CGFloat = 3.8       // 指数衰减
        var frameInterval: TimeInterval = 1/60
    }
    private var glideVelocity: CGVector?
    private var glideTimer: Timer?

    func onDragBegan()                    // -> semantic .dragging
    func onDragMoved(to origin: CGPoint)  // 跟随，气泡跟随
    func onDragEnded(velocity: CGVector)  // 判断：投掷 / 回 dock 判定
    func startWalk(to target: CGPoint, speed: CGFloat)  // 沿用 NSAnimationContext 缓动 or Timer 步进
    func dockIfNeeded(at origin: CGPoint) // 现有 handleDocking 逻辑搬入
    func recoverIfScreenChanged()         // 显示器变化 → 唤回可视区
}
```

- 行走方向：`velocity.dx` 符号 → `.walking(.left/.right)`，切换时保留当前帧（mod 帧数）保证连贯。
- dock：沿用现有边缘判定与台词，但**台词走命令**（`handle(.speak)`），不再直接写 model。

### 4.5 气泡控制器 BubbleController（线程化）

```swift
struct BubbleItem: Identifiable {
    let threadId: String
    var title: String?
    var text: String
    var kind: SpeakKind            // 决定图标/颜色（映射现有 PetMessageType）
    var status: BubbleStatus       // working | review | done | failed | waiting | info
    var actions: [PetAction]
    var createdAt: Date
    var ttl: TimeInterval?         // nil=手动关；到点自动折叠
}

@MainActor
final class BubbleController {
    private(set) var items: [BubbleItem] = []   // 可多任务堆叠

    func upsert(_ update: BubbleUpdate)   // threadId 相同 → 原地更新并触发状态动画
    func dismiss(threadId: String)
}
```

迁移：现有 `NearNotification` 若带 `threadId`，则走 `upsert`；不带则自动生成新 id（兼容现状）。

### 4.6 Ambient 调度器（取代散落 Timer）

现有 1s / 30s / 60s 分时逻辑（`updateState` / `updateSystemAwareness` / `updateIntentAwareness` / `updateHealthReminders`）保留语义，但统一为**可取消的调度表**，且尊重 `PowerStateManager.isIdle`（闲置即整体挂起——现有已做，保留）：

```swift
@MainActor
final class AmbientScheduler {
    struct Task { let key: String; let interval: TimeInterval; let block: () -> Void }
    func schedule(_ tasks: [Task])
    func suspend() / resume()     // idle 进出
}
```

> 现有 `PetManager` 中真正的定时器只有 1s 的 `checkTimer` + 各“距上次时间”判断，这部分收敛成本低。

### 4.7 渲染层

- `PetContentView` 改为读取 `PetRenderSnapshot`（由 Director 产出），只做“画当前帧”：
  - Lottie 路径：沿用 `LottieView`，播放语义化（playing/stopped + 指定 animation 名）。
  - 雪碧图路径：新增 `SpriteAtlasView`（NSView/NSHostingView 均可），本质是 `CALayer.contents = atlas 的第 row,col 裁剪`。行/列/帧时长来自 `pet.json`。
- `BubbleContentView` 改为消费 `BubbleController.items`（多气泡堆叠，如上方叠加）。

`PetAnimationResolver` 的定位变化：从“分散判断”变成“语义 → 渲染指令映射表”（查 manifest 的 animation 行），职责清晰且可换肤。

### 4.8 资源包 PetBundle（换肤 / 复用生态资产）

```text
~/Library/Application Support/Near-Swift/Pets/<pet-id>/
├── pet.json          # { id, displayName, description, source: lottie|spriteAtlas, ... }
└── spritesheet.webp  # 或 animation.json (Lottie)
```

- `PetLibrary`（参考 OpenPetsKit）：扫描内置 bundle + 用户目录 + `~/.codex/pets`（**兼容直接加载 codex 生态宠物**）。
- 启动默认内置 `guaishou`（Lottie）；用户可选择安装别的。

`pet.json`（合并生态字段，扩展我们的动画语义）：
```json
{
  "id": "my-pet",
  "displayName": "My Pet",
  "source": "spriteAtlas",
  "spritesheet": "spritesheet.webp",
  "atlas": { "cols": 8, "rows": 9, "cell": 192 },
  "rows": {
    "idle":        { "row": 0, "durationsMS": [280,110,110,140,140,320], "loop": true },
    "walkingLeft": { "row": 2, "durationsMS": [120,120,120,120,120,120,120,220], "loop": true },
    "walkingRight":{ "row": 1, "durationsMS": [120,120,120,120,120,120,120,220], "loop": true },
    "waving":      { "row": 3, "durationsMS": [140,140,140,280], "loop": false },
    "success":     { "row": 4, "durationsMS": [140,140,140,140,280], "loop": false },
    "failure":     { "row": 5, "durationsMS": [140,140,140,140,140,140,140,240], "loop": false },
    "waiting":     { "row": 6, "durationsMS": [150,150,150,150,150,280], "loop": true }
  }
}
```
> 缺行时自动 fallback 到内置兜底动画（如 review→waiting），保证任何半成品包都能跑不崩。

---

## 5. 落地阶段划分（每阶段可独立交付、可验证）

### Phase 1：状态收口 + 语义动画（中等改动，收益最大）
- 新增 `PetDirector`、`PetCommand`、`AnimStateMachine`、`PetAnimSemantic`。
- `PetManager` 现有通知/监控逻辑保留，改为向 director 发命令；拖拽/行走/dock 事件接入。
- 用 Lottie 继续渲染，但把 `guaishou` 拆成“语义→动画片段”（复用现有 Lottie 循环即可，先不做多文件）。
- 删除 0.5s isDragging 兜底 Timer，改由窗口事件可靠链路（`mouseDown/up` + `windowDidMove`）驱动。
- 验收：现有功能不回归；动画状态推导集中一处；单测覆盖状态机（不用窗口，注入 fake surface）。

### Phase 2：SpriteAtlas 渲染器 + 皮肤包
- 新增 `SpriteAtlasView` + `PetBundle/PetLibrary`。
- 内置 1 套 8×9 契约雪碧图（或直接兼容加载 `~/.codex/pets` 任意一只验证）。
- `PetAnimationResolver` 改为查 `pet.json` 的 rows。
- 验收：能渲染 & 切换语义动画；换 pet.json 即可换宠物；帧时长可配。

### Phase 3：外部输入层（IPC/MCP）+ CLI
- 本地 Unix socket 服务（`/tmp/near-pet-UID.sock`）接收 Codable `PetCommand`。
- 可选薄 MCP server（对齐 openpets 的 MCP 工具面）让 Codex/Claude 能 `notify`。
- `threadId` 气泡线程化落地（BubbleController）。
- 验收：`echo '{"type":"speak",...}' | nc -U /tmp/...` 能让宠物说话；同一 thread 更新气泡。

### Phase 4（可选）：投掷物理 + 屏幕变化唤回 + 位置持久化
- `MotionController` 补齐 Launch 滑行、屏幕拔插恢复、`positions.json`。

---

## 6. 风险与注意点

1. **Lottie ↔ 雪碧图并存期的渲染一致性**：两套渲染器都要消费同一 `PetRenderSnapshot`，避免“Lottie 有说话态、雪碧图没有”导致画面空白 → 统一走 fallback 表。
2. **状态机收敛不要一次到位**：先“新状态机 + 旧逻辑并存”灰度（Phase 1 明确说了），避免大爆炸回归。
3. **windowDidMove 触发噪音**：拖拽时 setFrame 会产生大量 move 事件，需按“按下状态”过滤，避免把行走/dock 误判为拖拽。
4. **闲置省电是现有优点**：任何新 Timer（帧调度、glide 60fps）都必须遵守 `PowerStateManager.isIdle` 挂起，避免把桌宠做成电老虎（生态里 OpenPets 也是 idle 停帧）。
5. **雪碧图大图内存**：1536×1872 整图放内存约 11MB，可只裁当前行到小图，或按需生成行纹理。
6. **安全**：IPC 只监听 127.0.0.1 / 本地 socket；`PetCommand.speak` 的 text 长度限流，防刷屏。

---

## 7. 借鉴来源清单

| 项目 | 仓库 | 借鉴点 |
|------|------|--------|
| awesome-codex-pet | github.com/legeling/awesome-codex-pet | 8×9 雪碧图契约、动画行定义、QA 校验 |
| OpenPets | github.com/alterhq/openpets | 单一 Host、MCP/CLI/socket 输入、plugin surface |
| OpenPetsKit | github.com/alterhq/OpenPetsKit | PetBundle/PetAnimation/PetCommand、投掷物理、帧调度、threadId 气泡 |

> 许可注意：借鉴的是**架构与协议设计**（MIT 项目可参考），宠物美术资产各有其许可（awesome-codex-pet 资产为 CC BY-NC 4.0，商用需注意；本项目接入时优先使用自有/宽松许可资产）。

---

## 附录 A：落地状态（2026-09-07 更新）

已按 Phase 1 + Phase 2 实现首轮改造，中文风格语义 + 社区皮肤兼容：

### 已完成

| 模块 | 文件 | 说明 |
|------|------|------|
| 语义枚举 | `Models/PetAtlas.swift` | `PetAnimSemantic`（闲置/行走/拖拽/说话/待命/忙碌/评审/成功/失败/贴边/低电量），`atlasClip(facing:)` 语义→行映射，8×9 契约 `SpriteAtlas`（行缓存裁剪） |
| 气泡线程化 | `Models/PetBubble.swift` | 中文 `PetMessageType`（原 PetModel 内定义移出），`BubbleStatus`（进行中/待评审/完成/失败…），`PetBubble.threadId`，`PetAction` |
| 皮肤包 | `Services/PetBundle.swift` | `PetManifest`（lottie/spriteAtlas 双源）、`PetBundle.load`、`PetLibrary`（内置 Lottie ×2 + App Support + `~/.codex/pets` 社区目录 + bundle 内 `Resources/Pets`），manifest 缺失字段容错 |
| 状态机宿主 | `Services/PetDirector.swift` | 单一驱动：`interrupt(_:reason:ttl:)` 抢占 + TTL 回闲置、`reconcile(reason:)` 状态归并、帧级 `Timer` 按帧时长调度、`entryFrame`、闲置 `suspend/resume` |
| 雪碧图渲染 | `Views/SpriteAtlasView.swift` | 读 `model.atlasRow/atlasCol` 裁剪显示，朝向/贴边缩放对齐旧 Lottie 行为 |
| 视图接线 | `Views/PetContentView.swift` / `PetWindow.swift` | 按 `PetBundle.isLottie` 分流：Lottie 走原播放器；atlas 走 `SpriteAtlasView` |
| 业务接入 | `Services/PetManager.swift` | `showPet` 解析皮肤、雪碧图皮肤创建 director；拖拽/说话/行走/dock 事件 → director 语义；`setSkin(id:)` 运行时换肤 + UserDefaults 持久化；启动 `loadStoredSkin` |
| 设置 UI | `Views/SettingsView.swift` | 「桌宠设置」新增"宠物形象"二列网格选择（内置怪兽/舞娘 + 已安装社区宠物） |
| 资源 | `Package.swift` + `Resources/Pets/starcorn/` | 内置示例社区皮肤（OpenPets starcorn，MIT，8×9 雪碧图） |

### 验证
- `swift build` 通过、无警告（含 Package exclude 清理 docs/ 等非代码文件）。
- CLI 冒烟：真实 1536×1872 雪碧图 `SpriteAtlas.load` 成功、8 列逐帧可裁、语义→行映射符合契约（闲置 0 / 右行 1 / 左行 2 / 说话 3 / 成功 4 / 失败 5 / 忙碌 7）。
- 皮肤扫描：`PetLibrary` 可发现内置 starcorn 与 `~/.codex/pets` 社区包。

### 未做（后续）
- `BubbleController` 多气泡堆叠与 `BubbleStatus`→动画联动尚未在 UI 全量接线（模型已备，`BubbleContentView` 仍单气泡）。
- 拖拽投掷物理 `PetLaunchMotion`、屏幕变化唤回、位置持久化（Phase 4）未做。
- `PetDirector` 目前只驱动雪碧图帧；Lottie 皮肤仍走旧 `PetAnimationResolver`（未统一到语义）。
- 社区宠物一键导入入口（curl 安装）尚未在 UI 提供，靠手动放目录。

### 静默闲置策略（2026-09-07 补记）

社区版雪碧图皮肤此前闲置时会"一直循环呼吸动画"，观感吵且耗资源。已优化：

- **闲置**：切到闲置后只播放 1 轮呼吸（约 6 帧 / 1s），然后**停帧静置**（保持末帧，不再驱动 Timer）。
- **偶发微动**：静置期间每 6s 一个微动 Timer，快速眨眼/轻动 2 帧（约 0.12s）后回到静置帧——"活着但不吵"。
- **一次性动作**（说话/成功/失败）播 2 轮回闲置；**忙碌/待命/评审/行走**持续循环（这些是"有事情"）。
- **贴边/低电量**：完全静止。
- 任何微动/循环 Timer 都受 `suspend()`（闲置抑制/隐藏）与 TTL 回闲约束，不存在常驻高频帧 Timer。

> 渲染侧同步配合：`SpriteAtlasView` 改为 CALayer `contentsRect` 方案——整图只上传一次到 GPU，换帧只改可视矩形，静置时零重绘；对比旧的 Lottie 每帧 CPU 参与 + 常驻 1s/0.5s 双 Timer，闲置功耗显著更低。

### 外部 Agent 接入（PI Hook 方案，2026-09-07 落地）

**结论**：PI 这类 CLI Agent 不应通过 MCP "让模型主动调用"来通知宠物，而应使用其**生命周期 Hook**——宿主保证触发、不占模型上下文。PI 支持 TypeScript Hook（`~/.pi/agent/hooks/*.ts` 自动发现），事件含 `session_start / agent_start / agent_end / tool_result(isError) / session_shutdown` 等。

**架构**：
```
PI (Hook: near-pet.ts) ──TCP 127.0.0.1:47521──▶ PetCommandServer (Swift, 回环)
     │                                               │ JSON 一行协议
     │  {"semantic":"success|failure|working|...","message":"可选"}
     ▼                                               ▼
  agent_start → working(原地跑)                  PetManager.onCommand
  tool_result isError → failure(沮丧)              ├─ 动作 → PetDirector.interrupt(semantic)
  agent_end (无错) → success(跳跃)                 └─ 台词 → saySomething
```

**落地文件**：
- `Services/PetCommandServer.swift`：`NWListener` 绑定回环 47521，解析一行 JSON，回调主线程；只接受 127.0.0.1 连接。
- `PetManager.startCommandServer()`：随 `showPet()` 启动、`hidePet()` 停止；收到命令 → 动作 + 可选台词。
- `docs/pi-near-pet-hook.ts`：PI Hook 模板（安装到 `~/.pi/agent/hooks/near-pet.ts`），映射 agent_start→working、工具错误→failure、agent_end→success、session 生命周期→idle。

**验证**：网络收发链路已用独立 harness 实测（listener ↔ client JSON 收发正常）；Hook 语法经 node --check 通过。App ↔ Hook 全链路需运行 App 后实测。

**端口约定**：`47521`（回环，见 `PetCommandServer.port`）。

### 远程命令体验优化（2026-09-08）

修复远程（PI Hook）动作被本地行为打断、动作与台词打架的问题：

1. **动作优先，台词不抢戏**：`PetManager.startCommandServer` 重构为——
   - `working/waiting/review`：循环动作 + 可选台词（台词走气泡但保留动作）
   - `success/failure`：播放完整一次性动作（跳跃/沮丧，TTL 3s）+ 台词并行
   - `idle`：回待命
   - `saySomething` 新增 `preserveAction` 参数：为 true 时只显示气泡，不再强制切 `.speaking`（挥手）——避免"成功跳跃刚起跳就被说话打断"。
2. **随机散步不打断表达性动作**：`handleSelfAwareness` 增加 `isExpressiveSemantic` 检查——忙碌/成功/失败/说话展示期间不随机散步。
3. **远程动作到达先停行走**：表达性命令若在随机散步中，先 `stopWalking` 再播动作，避免窗口还在移动、画面已是别的动作。

效果：PI 报告"构建成功"时，宠物会完整跳一下（而非只挥挥手）；忙碌状态不会被随机散步打断。

### v2 更新（2026-09-08）：纯社区宠物 + PI 一键接入 + 台词拟人化

1. **移除内置 Lottie 宠物（怪兽/舞娘）**：删除 `LottieView`、`Resources/lottie`、Lottie 依赖；桌宠统一为 codex 8×9 雪碧图社区宠物，内置示例为 `Resources/Pets/starcorn`（独角兽）。默认皮肤 `starcorn`。
2. **台词拟人化**：远程命令不再硬编码生硬文案（"任务完成!"），PetManager 按语义生成古风台词（成功→"成了成了！奴才给您贺喜~🎉" 等）；PI 扩展只发语义、不发文案，文案由 App 侧统一生成。
3. **设置页 PI 一键接入**：`Services/PIIntegration.swift` 管理 PI 扩展安装/卸载/状态；桌宠设置新增「PI 通知接入」卡片——检测 `~/.pi/agent/extensions/near-pet.ts` 是否已装、一键安装/卸载、状态提示。扩展监听 PI 生命周期（agent_start/agent_end/tool_execution_end）并把语义推给 App。
4. 旧 Lottie 动画状态机类型（`PetAnimationState/Descriptor/Resolver/Playback`）删除，`refreshAnimationState` 收敛为 `director.reconcile` 转发。
