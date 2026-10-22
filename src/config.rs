use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BrowserConfig {
    pub default_engine: String,      // "chromium" or "firefox"
    pub search_engine: String,       // "google", "duckduckgo", "brave", "bing", "ecosia"
    pub home_url: String,
    pub hardware_acceleration: bool,
    pub dark_mode: bool,
    pub restore_session: bool,
    pub zoom_level: f64,
    pub show_launcher_on_startup: bool,
}

impl Default for BrowserConfig {
    fn default() -> Self {
        Self {
            default_engine: "chromium".to_string(),
            search_engine: "google".to_string(),
            home_url: "https://www.google.com".to_string(),
            hardware_acceleration: true,
            dark_mode: true,
            restore_session: false,
            zoom_level: 1.0,
            show_launcher_on_startup: true,
        }
    }
}

pub fn config_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".config/focus/config.json")
}

pub fn load_config() -> BrowserConfig {
    let path = config_path();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(cfg) = serde_json::from_str::<BrowserConfig>(&content) {
            return cfg;
        }
    }
    let default_cfg = BrowserConfig::default();
    save_config(&default_cfg);
    default_cfg
}

pub fn save_config(cfg: &BrowserConfig) {
    let path = config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(cfg) {
        let _ = fs::write(path, json);
    }
}
