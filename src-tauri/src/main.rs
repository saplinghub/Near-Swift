#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use std::sync::{Arc, Mutex};
use sysinfo::{System, CpuRefreshKind, RefreshKind};
use tauri::image::Image;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tauri::{
    AppHandle, Manager, PhysicalPosition, PhysicalSize, Position,
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    menu::{MenuBuilder, MenuItemBuilder},
};
use tauri_plugin_store::StoreExt;
use chrono::{Local, NaiveDateTime, TimeZone};
use serde_json::json;
use std::thread;

#[tauri::command]
async fn get_countdowns(app: AppHandle) -> Result<Vec<serde_json::Value>, String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    Ok(store
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default())
}

#[tauri::command]
async fn save_countdown(app: AppHandle, countdown: serde_json::Value) -> Result<(), String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default();

    if let Some(id) = countdown.get("id").and_then(|v| v.as_str()) {
        if let Some(pos) = list.iter().position(|c| c.get("id").and_then(|v| v.as_str()) == Some(id)) {
            list[pos] = countdown.clone();
        } else {
            list.push(countdown);
        }
    }

    // 重新声明 store 用于写入
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(())
}

#[tauri::command]
async fn delete_countdown(app: AppHandle, id: String) -> Result<(), String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default();
    list.retain(|c| c.get("id").and_then(|v| v.as_str()) != Some(&id));
    
    // 重新声明 store 用于写入
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(())
}

#[tauri::command]
async fn pin_countdown(app: AppHandle, id: String) -> Result<Vec<serde_json::Value>, String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default();

    for item in &mut list {
        if let Some(map) = item.as_object_mut() {
            map.insert("pinned".into(), json!(false));
        }
    }
    if let Some(item) = list.iter_mut().find(|c| c.get("id").and_then(|v| v.as_str()) == Some(&id)) {
        if let Some(map) = item.as_object_mut() {
            map.insert("pinned".into(), json!(true));
        }
    }

    // 重新声明 store 用于写入
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(list)
}

#[tauri::command]
async fn get_system_stats() -> Result<serde_json::Value, String> {
    let mut sys = System::new_all();
    sys.refresh_all();

    // CPU 使用率
    let cpu_usage = sys.global_cpu_info().cpu_usage();

    // 内存使用情况
    let total_memory = sys.total_memory();
    let used_memory = sys.used_memory();
    let memory_usage = (used_memory as f64 / total_memory as f64) * 100.0;

    // 温度（Mac 系统）
    let temperature = if cfg!(target_os = "macos") {
        // 尝试从 ioreg 获取温度信息
        std::process::Command::new("sh")
            .arg("-c")
            .arg("ioreg -l | grep '\"TC0C\"' | awk '{print $4}' | sed 's/[^0-9]//g'")
            .output()
            .map(|output| {
                let temp_str = String::from_utf8_lossy(&output.stdout);
                if let Ok(temp) = temp_str.trim().parse::<f64>() {
                    // 转换为摄氏度
                    Some((temp - 273.15) / 10.0)
                } else {
                    None
                }
            })
            .unwrap_or(None)
    } else {
        None
    };

    Ok(json!({
        "cpu": cpu_usage,
        "memory": memory_usage,
        "temperature": temperature,
        "total_memory": total_memory,
        "used_memory": used_memory
    }))
}

#[tauri::command]
async fn get_ai_config(app: AppHandle) -> Result<Option<serde_json::Value>, String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?; // 移除 mut 警告
    Ok(store.get("ai_config").map(|v| v.clone()))
}

#[tauri::command]
async fn save_ai_config(app: AppHandle, config: serde_json::Value) -> Result<(), String> {
    // 需要 mut store 来 set 和 save
    let store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("ai_config", config);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

fn calculate_days(target: &str) -> i64 {
    let Ok(dt) = NaiveDateTime::parse_from_str(target, "%Y-%m-%dT%H:%M") else {
        return 0;
    };
    let Some(target_dt) = Local.from_local_datetime(&dt).single() else {
        return 0;
    };
    let duration = target_dt.signed_duration_since(Local::now());
    duration.num_days() + if duration.num_seconds() % 86400 > 0 { 1 } else { 0 }
}

fn create_animated_icon(cpu_usage: f32) -> Result<Vec<u8>, String> {
    let size = (32, 32);
    let mut image = image::RgbImage::new(size.0, size.1);

    // 根据CPU使用率创建动态效果
    let intensity = (cpu_usage / 100.0) as f64;
    let speed = (1.0 - intensity) * 0.1 + 0.05; // CPU越高，动画越快

    // 创建渐变背景
    for y in 0..size.1 {
        for x in 0..size.0 {
            let r = (99.0 + intensity * 156.0) as u8;
            let g = (102.0 + (1.0 - intensity) * 100.0) as u8;
            let b = (241.0 - intensity * 50.0) as u8;

            image.put_pixel(x, y, image::Rgb([r, g, b]));
        }
    }

    // 添加动态圆圈
    let center_x = size.0 / 2;
    let center_y = size.1 / 2;
    let time = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as f64;

    let radius = 8.0 + (time * speed).sin() * 3.0;
    let alpha = (time * speed * 2.0).sin() * 0.3 + 0.7;

    for y in 0..size.1 {
        for x in 0..size.0 {
            let dx = x as f64 - center_x as f64;
            let dy = y as f64 - center_y as f64;
            let distance = (dx * dx + dy * dy).sqrt();

            if distance <= radius {
                let pixel = image.get_pixel(x, y);
                let fade = (1.0 - distance / radius) * alpha;
                let new_r = (pixel[0] as f64 * (1.0 - fade) + 255.0 * fade) as u8;
                let new_g = (pixel[1] as f64 * (1.0 - fade) + 255.0 * fade) as u8;
                let new_b = (pixel[2] as f64 * (1.0 - fade) + 255.0 * fade) as u8;

                image.put_pixel(x, y, image::Rgb([new_r, new_g, new_b]));
            }
        }
    }

    let mut icon_data = Vec::new();
    image.write_to(&mut std::io::Cursor::new(&mut icon_data), image::ImageFormat::Png)
        .map_err(|e| e.to_string())?;

    Ok(icon_data)
}

fn update_tray_title(app: &AppHandle) {
    if let Some(tray) = app.tray_by_id("main-tray") {
        let store = app.store("store.json").map_err(|e| e.to_string()).unwrap();
        let list: Vec<serde_json::Value> = store
            .get("countdowns")
            .and_then(|v| v.as_array().map(|a| a.clone()))
            .unwrap_or_default();

        let title = if let Some(pinned) = list.iter().find(|c| c.get("pinned").and_then(|v| v.as_bool()) == Some(true)) {
            if let Some(date) = pinned.get("date").and_then(|v| v.as_str()) {
                let days = calculate_days(date);
                format!("{}天", days)
            } else {
                String::new()
            }
        } else {
            String::new()
        };

        let _ = tray.set_title(if title.is_empty() { None } else { Some(&title) });
    }
}

fn start_cpu_fan_tray(app: AppHandle) {
    println!("🚀 [风车动画] 启动风车动画线程");

    if let Some(tray) = app.tray_by_id("main-tray") {
        println!("🚀 [风车动画] 找到托盘图标，开始加载风车帧");

        // 预加载所有风车帧
        let frames: Vec<Image> = (0..32)
            .map(|i| {
                let path = format!("icons/fan_frames/fan_{:02}.png", i);
                println!("🔍 [风车动画] 加载风车帧: {}", path);
                let icon_bytes = std::fs::read(&path).expect(&format!("failed to read fan frame: {}", path));
                let icon = image::load_from_memory(&icon_bytes)
                    .expect(&format!("failed to load fan frame: {}", path))
                    .to_rgba8();
                let (width, height) = icon.dimensions();
                Image::new_owned(icon.into_raw(), width, height)
            })
            .collect();

        println!("🚀 [风车动画] 已加载 {} 张风车帧", frames.len());

        let sys = Arc::new(Mutex::new(System::new_with_specifics(
            RefreshKind::new().with_cpu(CpuRefreshKind::new().with_cpu_usage())
        )));
        let tray_ref = Arc::new(tray);

        thread::spawn(move || {
            let mut sys = sysinfo::System::new();  // 只需要 new 一次，不用 RefreshKind
            let mut current_fps = 15u32;
            let mut last_frame_time = std::time::Instant::now();
            let mut frame_index = 0;

            loop {
                // 关键！每 2 秒才真正刷新一次 CPU，其他时间直接读缓存
                if last_frame_time.elapsed().as_millis() > 2000 {
                    sys.refresh_cpu_specifics(sysinfo::CpuRefreshKind::new().with_cpu_usage());
                    last_frame_time = std::time::Instant::now();
                }

        // 直接读缓存值，几乎零开销
        let cpu_usage = sys.global_cpu_info().cpu_usage();

        // 根据 CPU 计算目标 fps：0% → 15fps，100% → 60fps
        let current_fps = 15 + ((cpu_usage * 45.0 / 100.0) as u32).min(60);

        // 用真实时间戳驱动动画（永不卡顿）
        let elapsed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis();

        let index = ((elapsed / (1000u128 / current_fps as u128)) % frames.len() as u128) as usize;

        if index != frame_index {
            if let Err(e) = tray_ref.set_icon(Some(frames[index].clone())) {
                eprintln!("❌ 图标更新失败: {}", e);
            }
            frame_index = index;
        }

        // 睡 50ms，CPU 低的时候自然更省
        std::thread::sleep(std::time::Duration::from_millis(50));
            }
        });
    } else {
        println!("❌ [风车动画] 未找到托盘图标 'main-tray'");
    }
}

pub fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .setup(|app| {
            let quit = MenuItemBuilder::with_id("quit", "退出").build(app)?;
            let menu = MenuBuilder::new(app).items(&[&quit]).build()?;

            let icon_bytes = include_bytes!("../icons/Near.png");
            let icon = image::load_from_memory(icon_bytes)
                .map_err(|e| format!("Failed to load icon: {}", e))?
                .to_rgba8();
            let (width, height) = icon.dimensions();
            let icon_image = Image::new_owned(icon.into_raw(), width, height);
            let app_handle = app.handle().clone();

            TrayIconBuilder::with_id("main-tray")
                .icon(icon_image)
                .icon_as_template(true)
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(move |app, event| {
                    if event.id() == "quit" {
                        app.exit(0);
                    }
                })
                .on_tray_icon_event(move |_tray, event| {
                    match event {
                        TrayIconEvent::Click {
                            button: MouseButton::Left,
                            button_state: MouseButtonState::Up,
                            rect,
                            ..
                        } => {
                            if let Some(win) = _tray.app_handle().get_webview_window("main") {
                                let is_visible = win.is_visible().unwrap_or(false);

                                if is_visible {
                                    let _ = win.hide();
                                } else {
                                    let pos: PhysicalPosition<i32> = rect.position.to_physical(1.0);
                                    let size: PhysicalSize<u32> = rect.size.to_physical(1.0);
                                    let win_size = win.outer_size().unwrap_or(PhysicalSize::new(380, 600));
                                    let x = pos.x - (win_size.width as i32 / 2) + (size.width as i32 / 2);
                                    let y = pos.y + size.height as i32;

                                    let _ = win.set_position(Position::Physical(PhysicalPosition::new(x, y)));
                                    let _ = win.show();
                                    let _ = win.set_focus();
                                }
                            }
                        }
                        _ => {}
                    }
                })
                .build(app)?;

            // 启动 CPU 风车动画
            start_cpu_fan_tray(app.handle().clone());

            // 失焦自动隐藏窗口
            if let Some(win) = app.get_webview_window("main") {
                let handle = app_handle.clone();
                win.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        if let Some(w) = handle.get_webview_window("main") {
                            let _ = w.hide();
                        }
                    }
                });
            }

            // 定时更新标题
            let app_handle = app.handle().clone();
            thread::spawn(move || loop {
                update_tray_title(&app_handle);
                thread::sleep(Duration::from_secs(60)); // 每60秒更新一次
            });

            update_tray_title(&app.handle());
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_countdowns,
            save_countdown,
            delete_countdown,
            pin_countdown,
            get_ai_config,
            save_ai_config,
            get_system_stats
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}