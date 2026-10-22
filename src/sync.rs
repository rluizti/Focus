use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BookmarkItem {
    pub title: String,
    pub url: String,
    pub folder: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HistoryItem {
    pub title: String,
    pub url: String,
    pub domain: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct SyncResult {
    pub source: String,
    pub bookmarks: Vec<BookmarkItem>,
    pub history: Vec<HistoryItem>,
}

fn extract_domain(url: &str) -> String {
    if let Some(stripped) = url.strip_prefix("https://").or_else(|| url.strip_prefix("http://")) {
        stripped.split('/').next().unwrap_or("").to_string()
    } else {
        url.to_string()
    }
}

fn collect_bookmarks_recursive(val: &serde_json::Value, current_folder: Option<&str>, out: &mut Vec<BookmarkItem>) {
    if let Some(arr) = val.as_array() {
        for item in arr {
            collect_bookmarks_recursive(item, current_folder, out);
        }
    } else if let Some(obj) = val.as_object() {
        let item_type = obj.get("type").and_then(|t| t.as_str()).unwrap_or("");
        let name = obj.get("name").and_then(|n| n.as_str()).unwrap_or("");

        if item_type == "url" {
            if let Some(url) = obj.get("url").and_then(|u| u.as_str()) {
                out.push(BookmarkItem {
                    title: name.to_string(),
                    url: url.to_string(),
                    folder: current_folder.map(|s| s.to_string()),
                });
            }
        } else if item_type == "folder" {
            if let Some(children) = obj.get("children") {
                collect_bookmarks_recursive(children, Some(name), out);
            }
        }
    }
}

pub fn import_bookmarks(path: &Path) -> Vec<BookmarkItem> {
    let mut bookmarks = Vec::new();
    if let Ok(content) = fs::read_to_string(path) {
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
            if let Some(roots) = json.get("roots").and_then(|r| r.as_object()) {
                for (root_name, root_val) in roots {
                    if let Some(children) = root_val.get("children") {
                        collect_bookmarks_recursive(children, Some(root_name), &mut bookmarks);
                    }
                }
            }
        }
    }
    bookmarks
}

pub fn import_history(path: &Path, limit: usize) -> Vec<HistoryItem> {
    let mut history = Vec::new();
    let temp_copy = PathBuf::from(format!("/tmp/omabrowser_hist_copy_{}.sqlite", std::process::id()));

    if fs::copy(path, &temp_copy).is_err() {
        return history;
    }

    let query = format!(
        "SELECT url, title FROM urls WHERE url NOT LIKE 'chrome://%' AND url NOT LIKE 'about:%' ORDER BY last_visit_time DESC LIMIT {};",
        limit
    );

    let output = Command::new("sqlite3")
        .arg("-separator")
        .arg("\t")
        .arg(&temp_copy)
        .arg(&query)
        .output();

    let _ = fs::remove_file(&temp_copy);

    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        for line in stdout.lines() {
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 2 {
                let url = parts[0].trim();
                let title = parts[1].trim();
                if !url.is_empty() {
                    let domain = extract_domain(url);
                    let display_title = if title.is_empty() { domain.clone() } else { title.to_string() };
                    history.push(HistoryItem {
                        title: display_title,
                        url: url.to_string(),
                        domain,
                    });
                }
            }
        }
    }

    history
}

pub fn sync_from_chrome_or_chromium() -> SyncResult {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let candidates = [
        ("Google Chrome", PathBuf::from(&home).join(".config/google-chrome/Default")),
        ("Chromium", PathBuf::from(&home).join(".config/chromium/Default")),
    ];

    let mut result = SyncResult::default();

    for (name, dir) in &candidates {
        let bmark_file = dir.join("Bookmarks");
        let hist_file = dir.join("History");

        let mut found = false;
        if bmark_file.exists() && result.bookmarks.is_empty() {
            result.bookmarks = import_bookmarks(&bmark_file);
            found = true;
        }

        if hist_file.exists() && result.history.is_empty() {
            result.history = import_history(&hist_file, 150);
            found = true;
        }

        if found && result.source.is_empty() {
            result.source = name.to_string();
        }
    }

    result
}
