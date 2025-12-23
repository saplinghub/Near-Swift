# Near Countdown

<p align="center">
  <img src="Resources/icons/fan_frames/fan_00.png" width="80" alt="Near Logo">
</p>

<p align="center">
  <strong>macOS 状态栏高级倒计时应用 | Cyber-Mysticism Style Countdown</strong>
</p>

---

## ✨ 功能特性 (Feature)

### 📅 智能倒计时管理
- **自然语言创建**: 接入 AI (OpenAI API 兼容)，支持如 "距离春节还有多久" 等输入。
- **状态栏置顶**: 关键事件可固定至 macOS 菜单栏。
- **动态图标**: 支持多种内置图标选择。

### 🗓 智能日历与黄历
- **AI 宜忌**: 自动分析每日运势与传统宜忌。
- **农历支持**: 完整集成农历算法，标注传统节日。

### 📊 系统实时监控
- **动画联动**: 状态栏风扇图标旋转速度随 CPU 负载动态调整。
- **负载视图**: 实时展示 CPU、内存、磁盘占用。

---

## 🛠 技术路线 (Technical Stack)

| 领域 | 方案 | 描述 |
|------|------|------|
| **核心语言** | Swift 5.10 | 确保原生性能与最新系统特性支持 |
| **UI 视图** | SwiftUI | 声明式界面，实现毛玻璃 (Glassmorphism) 与平滑动画 |
| **异步处理** | Combine / Concurrency | 处理传感器监控与 AI 请求响应 |
| **数据持久化** | Codable / UserDefaults | 轻量级本地配置与事件存储 |
| **构建系统** | Swift Package Manager | 纯净的依赖管理 |

---

## 📁 项目结构 (Architecture)

```text
.
├── Package.swift           # SPM 依赖与构建配置
├── build-dmg.sh           # 图标转换与 DMG 打包自动化脚本
├── dist/                  # 构建产物 (DMG, App Bundle)
├── README.md               # 项目统一说明文档
├── App.swift              # 应用入口 (AppDelegate)
├── Info.plist             # 应用配置信息
├── Models/                # 数据结构
├── Services/              # 业务逻辑 (AIService, 监控系统, 状态栏管理)
├── Views/                 # UI 界面 (ContentView, 侧边栏, 设置)
├── Utils/                 # 辅助工具 (公农历转换等)
├── ViewModels/            # 状态视图模型
└── Resources/             # 静态资源 (AppIcon.icns, 动画序列帧)
```

> [!IMPORTANT]
> **结构极致重构说明**: 
> 1. 已彻底清除父级及子级目录中所有 Electron/Web 开发的历史残留文档。
> 2. 解决了所有嵌套文件夹问题，项目现采用 100% 扁平化的原生 Swift 工程结构。
> 3. 所有构建、运行及配置文件均已移动到当前工作区根目录。

---

## 🚀 快速启动 (Get Started)

1. **直接安装**: 下载 `dist/` 目录下的最新 `.dmg` 文件即可。
2. **源码开发**:
   ```bash
   swift run      # 直接运行
   ./build-dmg.sh # 重新构建带图标的安装包
   ```

---

## ⚙️ 配置建议
在设置中配置您的 API Key 以解锁 AI 智能解析与黄历分析功能。

---
<p align="center">Made with ❤️ for macOS by Sapling</p>
