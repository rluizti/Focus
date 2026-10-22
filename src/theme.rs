use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ThemeInfo {
    pub mode: String,
    pub background: String,
    pub surface: String,
    pub surface_variant: String,
    pub foreground: String,
    pub dim_foreground: String,
    pub accent: String,
    pub border: String,
    pub active_border: String,
    pub border_size: i32,
    pub selection: String,
    pub red: String,
    pub green: String,
    pub blue: String,
    pub font_family: String,
    pub corner_radius: i32,
}

impl Default for ThemeInfo {
    fn default() -> Self {
        Self {
            mode: "dark".to_string(),
            background: "#0c0b0c".to_string(),
            surface: "#141315".to_string(),
            surface_variant: "#1f1d21".to_string(),
            foreground: "#FAFCFB".to_string(),
            dim_foreground: "#8f8a8e".to_string(),
            accent: "#b59790".to_string(),
            border: "#3a3437".to_string(),
            active_border: "#ff9f0a".to_string(),
            border_size: 2,
            selection: "#584e51".to_string(),
            red: "#c38b7b".to_string(),
            green: "#87a9b0".to_string(),
            blue: "#b59790".to_string(),
            font_family: "Inter, 'Liberation Sans', sans-serif".to_string(),
            corner_radius: 8,
        }
    }
}

pub fn load_omarchy_theme() -> ThemeInfo {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let path = PathBuf::from(&home).join(".local/state/omarchy/current/theme/colors.toml");

    let mut theme = ThemeInfo::default();

    if let Ok(content) = fs::read_to_string(&path) {
        let mut map: HashMap<String, String> = HashMap::new();
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            if let Some((key, val)) = trimmed.split_once('=') {
                let k = key.trim().to_string();
                let v = val.trim().trim_matches('"').to_string();
                map.insert(k, v);
            }
        }

        if let Some(bg) = map.get("background") {
            theme.background = bg.clone();
        }
        if let Some(dark_bg) = map.get("dark_background") {
            theme.surface = dark_bg.clone();
        } else if let Some(bg) = map.get("background") {
            theme.surface = bg.clone();
        }
        if let Some(mut_col) = map.get("muted") {
            theme.surface_variant = mut_col.clone();
        }
        if let Some(fg) = map.get("foreground") {
            theme.foreground = fg.clone();
        }
        if let Some(dim) = map.get("dark_foreground") {
            theme.dim_foreground = dim.clone();
        }
        if let Some(acc) = map.get("accent") {
            theme.accent = acc.clone();
        }
        if let Some(bord) = map.get("active_border_color") {
            theme.border = bord.clone();
            theme.active_border = bord.clone();
        }
        if let Some(sel) = map.get("selection") {
            theme.selection = sel.clone();
        }
        if let Some(m) = map.get("mode") {
            theme.mode = m.clone();
        }
        if let Some(r) = map.get("red") {
            theme.red = r.clone();
        }
        if let Some(g) = map.get("green") {
            theme.green = g.clone();
        }
        if let Some(b) = map.get("blue") {
            theme.blue = b.clone();
        }
    }

    // Read rounding from theme's hyprland.lua
    let hypr_path = PathBuf::from(&home).join(".local/state/omarchy/current/theme/hyprland.lua");
    if let Ok(hypr_content) = fs::read_to_string(&hypr_path) {
        for line in hypr_content.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("rounding") && !trimmed.starts_with("rounding_power") {
                if let Some((_, val)) = trimmed.split_once('=') {
                    let cleaned = val.trim().trim_end_matches(',').trim();
                    if let Ok(r) = cleaned.parse::<i32>() {
                        theme.corner_radius = r;
                        break;
                    }
                }
            }
        }
    }

    // Query active compositor values via hyprctl for ground truth
    if let Ok(output) = Command::new("hyprctl").args(["getoption", "decoration:rounding"]).output() {
        if output.status.success() {
            let out_str = String::from_utf8_lossy(&output.stdout);
            for line in out_str.lines() {
                if let Some(val) = line.strip_prefix("int:") {
                    if let Ok(r) = val.trim().parse::<i32>() {
                        theme.corner_radius = r;
                        break;
                    }
                }
            }
        }
    }

    if let Ok(output) = Command::new("hyprctl").args(["getoption", "general:border_size"]).output() {
        if output.status.success() {
            let out_str = String::from_utf8_lossy(&output.stdout);
            for line in out_str.lines() {
                if let Some(val) = line.strip_prefix("int:") {
                    if let Ok(s) = val.trim().parse::<i32>() {
                        theme.border_size = s;
                        break;
                    }
                }
            }
        }
    }

    theme
}
