# Near 倒计时 - 项目文档

## 项目简介

Near 倒计时是一款基于 Tauri 2.0 + Vue 3 开发的 macOS 状态栏倒计时应用。核心理念：**越近越重要，越近越靠前**。

## 核心功能

### 1. 倒计时管理
- ✅ 创建/编辑/删除倒计时事件
- ✅ 实时显示剩余天数、小时、分钟
- ✅ 进度条可视化（基于开始时间和目标时间）
- ✅ 自动区分"进行中"和"已结束"事件
- ✅ 置顶功能（置顶事件显示在状态栏标题）
- ✅ 拖拽排序（使用 SortableJS）

### 2. 图标系统
- ✅ 5种预设图标：火箭、棕榈树、耳机、代码、礼物
- ✅ 每个图标有独立配色方案
- ✅ 图标选择器界面

### 3. AI 智能解析
- ✅ 自然语言输入（如"过年倒计时"、"今年的进度"）
- ✅ AI 自动解析事件名称、开始时间、目标时间
- ✅ 支持自定义 AI 配置（API URL、Key、模型）
- ✅ 连接测试功能

### 4. 状态栏集成
- ✅ macOS 状态栏图标
- ✅ 动态 CPU 风车动画（32帧，根据 CPU 使用率调整转速）
- ✅ 状态栏标题显示置顶事件倒计时
- ✅ 点击图标显示/隐藏主窗口
- ✅ 失焦自动隐藏

### 5. 系统监控
- ✅ CPU 使用率监控
- ✅ 内存使用监控
- ✅ 系统温度监控（macOS）
- ✅ 运行时间统计

### 6. 数据持久化
- ✅ 使用 tauri-plugin-store 本地存储
- ✅ 自动保存倒计时列表
- ✅ 保存 AI 配置
- ✅ 保存排序顺序

## 技术栈

### 前端
- **Vue 3** - 渐进式 JavaScript 框架
- **Vite 5** - 下一代前端构建工具
- **SortableJS** - 拖拽排序库

### 后端（Rust）
- **Tauri 2.0** - 跨平台桌面应用框架
- **serde/serde_json** - JSON 序列化/反序列化
- **chrono** - 日期时间处理
- **sysinfo** - 系统信息监控
- **image** - 图像处理（风车动画帧）
- **tauri-plugin-store** - 本地数据存储

### 构建工具
- **Cargo** - Rust 包管理器
- **npm** - Node.js 包管理器

## 项目结构

```
electron-demo/
├── src/                      # 前端源码
│   ├── App.vue              # 主组件（1500+ 行）
│   ├── ai-service.js        # AI 服务封装
│   └── index.html           # HTML 入口
├── src-tauri/               # Rust 后端
│   ├── src/
│   │   └── main.rs          # 主程序（400+ 行）
│   ├── icons/               # 应用图标
│   │   ├── Near.png         # 状态栏图标
│   │   └── fan_frames/      # 风车动画帧（32张）
│   ├── Cargo.toml           # Rust 依赖配置
│   └── tauri.conf.json      # Tauri 配置
└── package.json             # Node.js 依赖配置
```

## 重点技术说明

### 1. 多显示器支持（已知问题）

**问题描述**：
- macOS 多显示器环境下，点击状态栏图标时窗口可能显示在错误的显示器上
- 特别是主显示器（4K Retina）和副显示器（1080P）缩放比例不同时

**当前实现**：
```rust
// 简化版定位逻辑（main.rs:353-361）
let pos: PhysicalPosition<i32> = rect.position.to_physical(1.0);
let size: PhysicalSize<u32> = rect.size.to_physical(1.0);
let win_size = win.outer_size().unwrap_or(PhysicalSize::new(380, 600));
let x = pos.x - (win_size.width as i32 / 2) + (size.width as i32 / 2);
let y = pos.y + size.height as i32;
win.set_position(Position::Physical(PhysicalPosition::new(x, y)));
```

**已尝试的解决方案**：
1. ❌ 根据托盘图标尺寸推断显示器缩放因子
2. ❌ 遍历所有显示器匹配坐标范围
3. ❌ 使用 macOS 原生 API（NSWindow.setScreen_）- 导致崩溃
4. ❌ 先 hide() 清除位置记忆 + 多次 set_position()

**根本原因**：
- Tauri 2.0-2.5 在 macOS 多显示器环境下 `set_position()` 不稳定
- 系统会强制将窗口拉回主显示器或上次显示的显示器
- 需要 Tauri 2.6+ 的 `set_position_on_monitor()` API（项目当前版本不支持）

**临时解决方案**：
- 保持简化版代码，使用固定缩放因子 1.0
- 等待 Tauri 2.6+ 升级后使用官方 API

### 2. CPU 风车动画优化

**性能优化**：
```rust
// 关键优化点（main.rs:278-306）
// 1. 预加载所有32帧到内存
let frames: Vec<Image> = (0..32).map(|i| { /* 加载帧 */ }).collect();

// 2. 每2秒才刷新一次 CPU 数据（避免频繁系统调用）
if last_frame_time.elapsed().as_millis() > 2000 {
    sys.refresh_cpu_specifics(CpuRefreshKind::new().with_cpu_usage());
}

// 3. 使用时间戳驱动动画（永不卡顿）
let elapsed = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis();
let index = ((elapsed / (1000 / current_fps)) % frames.len()) as usize;

// 4. 根据 CPU 动态调整帧率：0% → 15fps，100% → 60fps
let current_fps = 15 + ((cpu_usage * 45.0 / 100.0) as u32).min(60);
```

**效果**：
- CPU 占用 < 1%
- 动画流畅不卡顿
- 实时反映系统负载

### 3. 拖拽排序实现

**关键逻辑**：
```javascript
// App.vue:284-386
sortableInstance = Sortable.create(container, {
  animation: 120,
  onEnd: (evt) => {
    const { oldIndex, newIndex } = evt;

    // 1. 创建带原始索引的副本
    const allItems = countdowns.value.map((item, index) => ({
      ...item,
      _originalIndex: index
    }));

    // 2. 找到在完整列表中的位置
    const oldIndexInAll = allItems.findIndex(item => item.id === oldItem?.id);
    const newIndexInAll = allItems.findIndex(item => item.id === newItem?.id);

    // 3. 移动项目并更新 order
    allItems.splice(oldIndexInAll, 1);
    allItems.splice(newIndexInAll, 0, movedItem);
    for (let i = 0; i < allItems.length; i++) {
      allItems[i].order = i;
    }

    // 4. 只保存移动的项目（避免批量写入）
    invoke('save_countdown', { countdown: movedItem });
  }
});
```

**难点**：
- 需要处理"进行中"和"已结束"两个过滤视图
- 拖拽在过滤视图中进行，但需要更新完整列表的 order
- 避免频繁保存所有项目（性能优化）

### 4. 失焦自动隐藏

**实现**：
```rust
// main.rs:374-383
win.on_window_event(move |event| {
    if let tauri::WindowEvent::Focused(false) = event {
        if let Some(w) = handle.get_webview_window("main") {
            let _ = w.hide();
        }
    }
});
```

**注意事项**：
- 必须在 `setup()` 中注册事件监听
- 使用 `clone()` 的 `app_handle` 避免生命周期问题

### 5. AI 服务集成

**架构**：
```javascript
// ai-service.js
class AIService {
  constructor(config) {
    this.baseURL = config.baseURL;
    this.apiKey = config.apiKey;
    this.model = config.model;
  }

  async parseCountdown(input) {
    // 1. 构造 prompt
    const prompt = `解析倒计时事件：${input}`;

    // 2. 调用 OpenAI 兼容 API
    const response = await fetch(`${this.baseURL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        model: this.model,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    // 3. 解析 JSON 响应
    const result = JSON.parse(response.choices[0].message.content);
    return {
      name: result.name,
      date: result.date,
      startDate: result.startDate
    };
  }
}
```

**支持的 API**：
- OpenAI API
- Azure OpenAI
- 任何 OpenAI 兼容的 API（如 Ollama、LocalAI）

## UI/UX 设计

### 设计语言
- **毛玻璃效果**：`backdrop-filter: blur(10px)`
- **柔和阴影**：多层低透明度阴影（已优化，避免黑线问题）
- **圆角设计**：12-20px 圆角
- **渐变色**：主色调 `#6366F1` → `#8B5CF6`

### 动画效果
- **滑入动画**：设置/表单页从右侧滑入
- **悬停效果**：卡片悬停时轻微抬起 + 阴影加深
- **FAB 按钮**：悬停时旋转90度 + 放大

### 响应式
- 固定窗口尺寸：380x600（逻辑像素）
- 自适应 Retina 显示器（2x 缩放）

## 已知问题

1. **多显示器定位不准确**（见上文详细说明）
2. **阴影效果调整**：用户反馈阴影有黑灰色线条（已尝试优化但用户不满意）
3. **温度监控不稳定**：macOS 温度获取依赖 `ioreg` 命令，可能返回 N/A

## 开发命令

```bash
# 开发模式
npm run tauri dev

# 构建生产版本
npm run tauri build

# 仅前端开发
npm run dev

# 仅后端编译
cd src-tauri && cargo build
```

## 依赖版本

### 前端
- Vue: 3.x
- Vite: 5.4.21
- SortableJS: 最新版

### 后端
- Tauri: 2.0
- Rust: 2021 edition
- sysinfo: 0.30
- chrono: 0.4
- image: 0.25

## 未来计划

- [ ] 升级到 Tauri 2.6+ 解决多显示器问题
- [ ] 添加通知提醒功能
- [ ] 支持自定义主题
- [ ] 导出/导入倒计时数据
- [ ] 支持 Windows/Linux 平台
- [ ] 添加快捷键支持
- [ ] 云同步功能

## 贡献者

- 主要开发：Sapling
- AI 辅助：Claude (Anthropic)

## 许可证

MIT License
