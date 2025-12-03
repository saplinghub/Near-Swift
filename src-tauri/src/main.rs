#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{Manager, SystemTray, SystemTrayEvent, SystemTrayMenu};
use tauri_plugin_store::StoreBuilder;

#[tauri::command]
fn get_countdowns(app: tauri::AppHandle) -> Result<Vec<serde_json::Value>, String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    Ok(store.get("countdowns").cloned().unwrap_or(serde_json::json!([])).as_array().unwrap().clone())
}

#[tauri::command]
fn save_countdown(app: tauri::AppHandle, countdown: serde_json::Value) -> Result<serde_json::Value, String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    let mut countdowns: Vec<serde_json::Value> = store.get("countdowns").cloned().unwrap_or(serde_json::json!([])).as_array().unwrap().clone();

    if let Some(id) = countdown.get("id") {
        if let Some(pos) = countdowns.iter().position(|c| c.get("id") == Some(id)) {
            countdowns[pos] = countdown.clone();
        } else {
            countdowns.push(countdown.clone());
        }
    }

    store.set("countdowns", serde_json::json!(countdowns));
    store.save().map_err(|e| e.to_string())?;
    Ok(countdown)
}

#[tauri::command]
fn delete_countdown(app: tauri::AppHandle, id: String) -> Result<(), String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    let mut countdowns: Vec<serde_json::Value> = store.get("countdowns").cloned().unwrap_or(serde_json::json!([])).as_array().unwrap().clone();
    countdowns.retain(|c| c.get("id").and_then(|v| v.as_str()) != Some(&id));
    store.set("countdowns", serde_json::json!(countdowns));
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
fn pin_countdown(app: tauri::AppHandle, id: String) -> Result<Vec<serde_json::Value>, String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    let mut countdowns: Vec<serde_json::Value> = store.get("countdowns").cloned().unwrap_or(serde_json::json!([])).as_array().unwrap().clone();

    for countdown in &mut countdowns {
        if let Some(obj) = countdown.as_object_mut() {
            obj.insert("pinned".to_string(), serde_json::json!(false));
        }
    }

    if let Some(countdown) = countdowns.iter_mut().find(|c| c.get("id").and_then(|v| v.as_str()) == Some(&id)) {
        if let Some(obj) = countdown.as_object_mut() {
            obj.insert("pinned".to_string(), serde_json::json!(true));
        }
    }

    store.set("countdowns", serde_json::json!(countdowns));
    store.save().map_err(|e| e.to_string())?;
    Ok(countdowns)
}

#[tauri::command]
fn get_ai_config(app: tauri::AppHandle) -> Result<Option<serde_json::Value>, String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    Ok(store.get("ai_config").cloned())
}

#[tauri::command]
fn save_ai_config(app: tauri::AppHandle, config: serde_json::Value) -> Result<serde_json::Value, String> {
    let store = app.state::<tauri_plugin_store::Store<tauri::Wry>>();
    store.set("ai_config", config.clone());
    store.save().map_err(|e| e.to_string())?;
    Ok(config)
}

fn main() {
    let tray_menu = SystemTrayMenu::new();
    let system_tray = SystemTray::new().with_menu(tray_menu);

    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::default().build())
        .system_tray(system_tray)
        .on_system_tray_event(|app, event| match event {
            SystemTrayEvent::LeftClick { .. } => {
                let window = app.get_window("main").unwrap();
                if window.is_visible().unwrap() {
                    window.hide().unwrap();
                } else {
                    window.show().unwrap();
                    window.set_focus().unwrap();
                }
            }
            _ => {}
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
