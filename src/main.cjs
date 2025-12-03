const { app, BrowserWindow, Menu, Tray, ipcMain, nativeImage, screen } = require('electron');
const path = require('path');
const fs = require('fs');

const isDev = process.env.ELECTRON_ENV === 'development';

let mainWindow = null;
let tray = null;
let currentIndex = 0;
let updateInterval = null;

const dataPath = path.join(app.getPath('userData'), 'countdowns.json');
const configPath = path.join(app.getPath('userData'), 'ai-config.json');

// 隐藏 Dock 图标
if (process.platform === 'darwin') {
  app.dock.hide();
}

const loadCountdowns = () => {
  try {
    if (fs.existsSync(dataPath)) {
      return JSON.parse(fs.readFileSync(dataPath, 'utf8'));
    }
  } catch (e) {}
  return [];
};

const saveCountdowns = (countdowns) => {
  fs.writeFileSync(dataPath, JSON.stringify(countdowns, null, 2));
};

const calculateDays = (targetDate) => {
  const now = new Date();
  const target = new Date(targetDate);
  const diff = target - now;
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
};

const updateTrayTitle = () => {
  const countdowns = loadCountdowns();
  const pinned = countdowns.find(c => c.pinned);

  if (pinned) {
    const days = calculateDays(pinned.date);
    // 只展示天数，使用更简洁的格式
    tray.setTitle(`⏳ ${days}天`);
  } else {
    tray.setTitle('⏳'); // 默认图标
  }
};

const createWindow = () => {
  mainWindow = new BrowserWindow({
    width: 380, // 调整为更适合状态栏下拉的宽度
    height: 600,
    show: false, // 初始不显示
    frame: false, // 无边框
    resizable: false, // 不可调整大小
    transparent: true, // 透明背景
    skipTaskbar: true, // 不在任务栏显示
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      backgroundThrottling: false, // 后台不节流
    },
  });

  const url = isDev
    ? 'http://localhost:5173'
    : `file://${path.join(__dirname, '../dist/index.html')}`;

  mainWindow.loadURL(url);

  // 失焦自动隐藏
  mainWindow.on('blur', () => {
    if (!mainWindow.webContents.isDevToolsOpened()) {
      mainWindow.hide();
    }
  });

  if (isDev) {
    // mainWindow.webContents.openDevTools({ mode: 'detach' });
  }
};

const toggleWindow = () => {
  if (mainWindow.isVisible()) {
    mainWindow.hide();
  } else {
    showWindow();
  }
};

const showWindow = () => {
  const trayBounds = tray.getBounds();
  const windowBounds = mainWindow.getBounds();
  
  // 获取当前 Tray 所在的屏幕
  const display = screen.getDisplayMatching(trayBounds);
  
  // 计算位置：水平居中于 Tray 图标
  let x = Math.round(trayBounds.x + (trayBounds.width / 2) - (windowBounds.width / 2));
  let y = Math.round(trayBounds.y + trayBounds.height);

  // 确保窗口不超出当前屏幕边界
  // x 轴边界检查
  if (x < display.bounds.x) {
    x = display.bounds.x;
  } else if (x + windowBounds.width > display.bounds.x + display.bounds.width) {
    x = display.bounds.x + display.bounds.width - windowBounds.width;
  }

  // y 轴边界检查 (通常 Tray 在顶部，所以 y 只需要考虑不超出底部，但在某些系统 Tray 可能在底部)
  // 这里假设 macOS 风格，Tray 在顶部。如果在底部，y 需要减去窗口高度。
  if (y + windowBounds.height > display.bounds.y + display.bounds.height) {
    y = trayBounds.y - windowBounds.height;
  }

  mainWindow.setPosition(x, y, false);
  mainWindow.show();
  mainWindow.focus();
};

const createTray = () => {
  const icon = nativeImage.createEmpty(); // 实际使用时应替换为真实图标
  tray = new Tray(icon);

  updateTrayTitle();

  // 移除默认的 contextMenu，改为点击事件处理
  // 只保留右键菜单用于退出
  const contextMenu = Menu.buildFromTemplate([
    { label: '退出', click: () => { app.isQuitting = true; app.quit(); } },
  ]);

  tray.on('right-click', () => {
    tray.popUpContextMenu(contextMenu);
  });

  tray.on('click', (event, bounds) => {
    // 切换窗口显示/隐藏
    toggleWindow();
    
    // 同时也可以轮播标题（可选，如果觉得冲突可以去掉）
    const countdowns = loadCountdowns();
    if (countdowns.length > 0) {
      currentIndex++;
      updateTrayTitle();
    }
  });

  tray.on('drop-text', (event, text) => {
      // 处理拖拽文本到托盘标（可选）
  });

  updateInterval = setInterval(updateTrayTitle, 60000);
};

app.on('ready', () => {
  createWindow();
  createTray();
});

// 阻止窗口关闭，改为隐藏
app.on('window-all-closed', () => {
  // 不做任何事，保持进程运行
});

ipcMain.handle('get-countdowns', () => {
  return loadCountdowns();
});

ipcMain.handle('save-countdown', (_event, countdown) => {
  const countdowns = loadCountdowns();
  const index = countdowns.findIndex(c => c.id === countdown.id);

  if (index >= 0) {
    // 保留原有的 pinned 状态，如果前端没传
    if (countdown.pinned === undefined) {
      countdown.pinned = countdowns[index].pinned;
    }
    countdowns[index] = countdown;
  } else {
    countdown.id = Date.now().toString();
    countdown.pinned = false; // 新建默认不置顶
    countdowns.push(countdown);
  }

  saveCountdowns(countdowns);
  updateTrayTitle();
  return countdown;
});

ipcMain.handle('delete-countdown', (_event, id) => {
  let countdowns = loadCountdowns();
  countdowns = countdowns.filter(c => c.id !== id);
  saveCountdowns(countdowns);
  updateTrayTitle();
});

ipcMain.handle('pin-countdown', (_event, id) => {
  const countdowns = loadCountdowns();
  // 先将所有项的 pinned 设为 false
  countdowns.forEach(c => c.pinned = false);
  
  // 找到目标项并设为 true
  const target = countdowns.find(c => c.id === id);
  if (target) {
    target.pinned = true;
  }
  
  saveCountdowns(countdowns);
  updateTrayTitle();
  return countdowns;
});

ipcMain.handle('get-ai-config', () => {
  try {
    if (fs.existsSync(configPath)) {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    }
  } catch (e) {}
  return null;
});

ipcMain.handle('save-ai-config', (_event, config) => {
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  return config;
});

app.on('before-quit', () => {
  if (updateInterval) clearInterval(updateInterval);
});