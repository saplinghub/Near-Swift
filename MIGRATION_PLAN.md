# Near 倒计时 - Swift/SwiftUI 迁移计划

## 项目概述

将现有的 Tauri 2.0 + Vue 3 应用迁移到原生 Swift/SwiftUI 实现，保持所有现有功能不变，并保持统一的视觉风格。

## 迁移目标

### 技术栈变更
- **前端**: Vue 3 → SwiftUI
- **后端**: Tauri (Rust) → 原生 Swift
- **构建工具**: Cargo + npm → Swift Package Manager (SPM) + Xcode
- **平台**: 跨平台 → macOS 专用（可考虑未来扩展）

### 功能保持
所有现有功能必须100%保留：
- 倒计时管理（CRUD、置顶、排序）
- 图标系统（5种预设图标）
- AI 智能解析
- 状态栏集成
- 系统监控（CPU、内存、温度）
- 数据持久化

## 迁移策略

### 阶段一：项目初始化（1-2天）

#### 1.1 创建新项目结构
```
NearCountdown/
├── NearCountdown/           # SwiftUI App
│   ├── Models/             # 数据模型
│   ├── Views/              # SwiftUI 视图
│   ├── ViewModels/         # MVVM 视图模型
│   ├── Services/           # 业务逻辑服务
│   ├── Utils/              # 工具类
│   └── Resources/          # 资源文件
├── NearCountdownKit/       # 共享框架
├── NearCountdownTests/    # 单元测试
└── NearCountdownUITests/  # UI 测试
```

#### 1.2 配置项目设置
- 创建 Xcode 项目（macOS App）
- 配置 SwiftUI + Combine
- 设置权限（状态栏、系统监控）
- 配置资源文件（图标、动画帧）

### 阶段二：数据层迁移（2-3天）

#### 2.1 数据模型设计
```swift
// CountdownEvent.swift
struct CountdownEvent: Identifiable, Codable {
    let id: UUID
    let name: String
    let startDate: Date
    let targetDate: Date
    let icon: IconType
    let isPinned: Bool
    let order: Int
}

// IconType.swift (5种图标对应)
enum IconType: String, CaseIterable, Codable {
    case rocket, palm, headphones, code, gift
}
```

#### 2.2 数据持久化
- 使用 `UserDefaults` + `Codable`
- 替换 tauri-plugin-store
- 保持相同的存储结构和键名

#### 2.3 配置管理
- AI 配置（API URL、Key、模型）
- 系统设置
- 保持 JSON 格式兼容

### 阶段三：核心功能实现（5-7天）

#### 3.1 倒计时管理
- SwiftUI 列表视图（使用 `List` + `ForEach`）
- 添加/编辑/删除功能
- 置顶功能（过滤列表）
- 排序功能（拖拽实现）

#### 3.2 图标系统
- SF Symbols 替换自定义图标
- 保持5种图标类型
- 保持配色方案
- 图标选择器界面

#### 3.3 AI 服务集成
- 使用 Swift 的 `URLSession`
- 保持 API 兼容性
- 错误处理和重试机制

#### 3.4 系统监控
- 使用 `ProcessInfo` CPU 监控
- 使用 `MemoryFormatter` 内存监控
- 使用 `Process` 调用 `ioreg` 获取温度

### 阶段四：状态栏集成（3-4天）

#### 4.1 状态栏应用
- 使用 `NSStatusItem`
- 图标显示和动画
- 点击事件处理

#### 4.2 CPU 风车动画
- Swift 重写动画逻辑
- 保持32帧动画
- 保持动态帧率调整

#### 4.3 窗口管理
- NSWindow + SwiftUI
- 点击状态栏显示/隐藏
- 失焦自动隐藏
- 多显示器支持（使用 NSScreen）

### 阶段五：UI/UX 实现（4-5天）

#### 5.1 视觉设计
- 毛玻璃效果（NSVisualEffectView）
- 柔和阴影（NSBox + 圆角）
- 渐变色（NSGradient）
- 保持现有设计语言

#### 5.2 交互动画
- SwiftUI 动画API
- 滑入/滑出效果
- 悬停效果
- FAB 按钮动画

#### 5.3 响应式设计
- 固定窗口尺寸
- Retina 显示器支持
- 自适应布局

### 阶段六：测试和优化（2-3天）

#### 6.1 功能测试
- 单元测试（ViewModel、Service）
- UI 测试（关键交互）
- 性能测试

#### 6.2 性能优化
- 内存管理优化
- 动画性能优化
- 启动速度优化

#### 6.3 兼容性测试
- macOS 版本兼容（10.15+）
- 不同显示器配置测试

## 技术实现细节

### SwiftUI vs Vue 3 对应关系

| Vue 3 | SwiftUI | 说明 |
|-------|---------|------|
| `v-model` | `@Binding` | 双向绑定 |
| `v-if` | `if/else` | 条件渲染 |
| `v-for` | `ForEach` | 列表渲染 |
| `@click` | `.onTapGesture` | 点击事件 |
| `ref` | `@StateObject` | 状态管理 |
| `computed` | `@Computed` | 计算属性 |
| `watch` | `onChange` | 监听变化 |

### 拖拽排序实现
```swift
// 使用 SwiftUI 的 .onDrag 和 .onDrop
List(countdowns) { item in
    Text(item.name)
        .onDrag { NSItemProvider(object: item.id as NSItemProviderWriting) }
}
.onDrop(of: [.data], delegate: DragDropDelegate())
```

### 状态栏动画
```swift
// 使用 NSImage + Timer 实现动画
class StatusBarManager: ObservableObject {
    private var animationTimer: Timer?
    private var currentFrame = 0

    func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            self.currentFrame = (self.currentFrame + 1) % 32
            self.updateStatusBarIcon()
        }
    }
}
```

### 多显示器支持
```swift
// 使用 NSScreen 获取正确的屏幕
func getWindowPosition() -> NSPoint {
    guard let screen = NSScreen.main,
          let mouseLocation =NSEvent.mouseLocation else {
        return .zero
    }

    // 根据鼠标位置确定当前屏幕
    let currentScreen = NSScreen.screens.first { screen in
        screen.frame.contains(mouseLocation)
    } ?? NSScreen.main

    return currentScreen.frame.origin
}
```

## 风险评估

### 高风险
1. **多显示器兼容性**：需要深入测试 NSWindow 在多显示器下的行为
2. **性能要求**：SwiftUI 的性能需要达到与 Tauri 相同的水平
3. **API 变更**：某些 macOS API 可能与 Tauri 实现不同

### 中风险
1. **开发速度**：Swift/SwiftUI 学习曲线
2. **依赖管理**：需要重新实现所有依赖功能
3. **测试覆盖**：需要完整的测试套件

### 低风险
1. **UI 实现**：SwiftUI 更适合 macOS 原生设计
2. **性能优化**：原生代码可能有更好的性能
3. **维护成本**：单一技术栈更易维护

## 迁移时间表

| 阶段 | 任务 | 预估时间 | 依赖 |
|------|------|----------|------|
| 一 | 项目初始化 | 1-2天 | 无 |
| 二 | 数据层迁移 | 2-3天 | 阶段一 |
| 三 | 核心功能 | 5-7天 | 阶段二 |
| 四 | 状态栏集成 | 3-4天 | 阶段三 |
| 五 | UI/UX 实现 | 4-5天 | 阶段四 |
| 六 | 测试优化 | 2-3天 | 阶段五 |

**总预估时间：17-24天**

## 成功标准

### 功能完整性
- [ ] 所有现有功能100%保留
- [ ] UI 视觉效果完全一致
- [ ] 用户体验保持一致

### 性能指标
- [ ] 启动时间 < 2秒
- [ ] CPU 占用 < 1%
- [ ] 内存占用 < 50MB
- [ ] 动画流畅度 60fps

### 代码质量
- [ ] 测试覆盖率 > 80%
- [ ] 代码遵循 Swift 编码规范
- [ ] 无内存泄漏
- [ ] 错误处理完善

## 后续计划

### 短期（1-2周）
- 完成迁移并发布测试版本
- 收集用户反馈
- 修复发现的问题

### 中期（1个月）
- 优化性能和用户体验
- 添加新功能（基于原计划）
- 准备 App Store 发布

### 长期（3个月）
- 考虑扩展到 iOS
- 添加云同步功能
- 支持更多平台

## 决策点

1. **继续迁移**：确认后开始阶段一实施
2. **调整计划**：根据实际情况调整时间表或功能优先级
3. **终止迁移**：如果发现重大问题，考虑其他方案

---

*创建日期：2025-12-09*
*分支：swift*
*状态：待批准*