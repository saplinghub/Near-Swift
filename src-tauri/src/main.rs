#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use tauri::{
    AppHandle, Manager, PhysicalPosition, PhysicalSize, Position,
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    menu::{MenuBuilder, MenuItemBuilder},
    image::Image,
};
use tauri_plugin_store::StoreExt;
use chrono::{Local, NaiveDateTime, TimeZone};
use serde_json::json;
use std::thread;
use std::time::Duration;

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
    // 移除 mut 警告 (只用于读取)
    let store_readonly = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store_readonly
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

    // 重新声明 mut store 用于写入
    let mut store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(())
}

#[tauri::command]
async fn delete_countdown(app: AppHandle, id: String) -> Result<(), String> {
    // 移除 mut 警告 (只用于读取)
    let store_readonly = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store_readonly
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default();
    list.retain(|c| c.get("id").and_then(|v| v.as_str()) != Some(&id));
    
    // 重新声明 mut store 用于写入
    let mut store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(())
}

#[tauri::command]
async fn pin_countdown(app: AppHandle, id: String) -> Result<Vec<serde_json::Value>, String> {
    // 移除 mut 警告 (只用于读取)
    let store_readonly = app.store("store.json").map_err(|e| e.to_string())?;
    let mut list: Vec<serde_json::Value> = store_readonly
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

    // 重新声明 mut store 用于写入
    let mut store = app.store("store.json").map_err(|e| e.to_string())?;
    store.set("countdowns", json!(list));
    store.save().map_err(|e| e.to_string())?;
    update_tray_title(&app);
    Ok(list)
}

#[tauri::command]
async fn get_ai_config(app: AppHandle) -> Result<Option<serde_json::Value>, String> {
    let store = app.store("store.json").map_err(|e| e.to_string())?; // 移除 mut 警告
    Ok(store.get("ai_config").map(|v| v.clone()))
}

#[tauri::command]
async fn save_ai_config(app: AppHandle, config: serde_json::Value) -> Result<(), String> {
    // 需要 mut store 来 set 和 save
    let mut store = app.store("store.json").map_err(|e| e.to_string())?;
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

fn update_tray_title(app: &AppHandle) {
    let Ok(store) = app.store("store.json") else { return };
    let list: Vec<serde_json::Value> = store
        .get("countdowns")
        .and_then(|v| v.as_array().map(|a| a.clone()))
        .unwrap_or_default();

    let title = if let Some(pinned) = list.iter().find(|c| c.get("pinned").and_then(|v| v.as_bool()) == Some(true)) {
        if let Some(date) = pinned.get("date").and_then(|v| v.as_str()) {
            let days = calculate_days(date);
            format!("{days}天")
        } else {
            String::new()
        }
    } else {
        String::new()
    };

    if let Some(tray) = app.tray_by_id("main-tray") {
        let _ = tray.set_title(if title.is_empty() { None } else { Some(&title) });
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
                .on_menu_event(|app, event| {
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
                thread::sleep(Duration::from_secs(60));
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
            save_ai_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}