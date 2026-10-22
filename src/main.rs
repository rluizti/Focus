mod config;
mod engines;
mod sync;
mod theme;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;

#[repr(C)]
pub struct RustCallbacks {
    pub on_config_saved: extern "C" fn(*const c_char),
    pub on_chrome_sync: extern "C" fn(*mut *mut c_char, *mut *mut c_char),
    pub on_switch_engine: extern "C" fn(*const c_char, *const c_char),
    pub free_string: extern "C" fn(*mut c_char),
}

unsafe extern "C" {
    fn oma_run_gui(
        argc: i32,
        argv: *mut *mut c_char,
        qml_file_path: *const c_char,
        initial_theme_json: *const c_char,
        initial_config_json: *const c_char,
        initial_bookmarks_json: *const c_char,
        initial_history_json: *const c_char,
        callbacks: RustCallbacks,
    ) -> i32;
}

extern "C" fn cb_config_saved(json: *const c_char) {
    if json.is_null() {
        return;
    }
    let c_str = unsafe { CStr::from_ptr(json) };
    if let Ok(str_slice) = c_str.to_str() {
        if let Ok(cfg) = serde_json::from_str::<config::BrowserConfig>(str_slice) {
            config::save_config(&cfg);
            println!("[OmaBrowser] Config saved successfully!");
        }
    }
}

extern "C" fn cb_chrome_sync(out_bookmarks: *mut *mut c_char, out_history: *mut *mut c_char) {
    let sync_result = sync::sync_from_chrome_or_chromium();
    println!(
        "[OmaBrowser] Synced {} bookmarks and {} history items from {}",
        sync_result.bookmarks.len(),
        sync_result.history.len(),
        sync_result.source
    );

    if let Ok(b_json) = serde_json::to_string(&sync_result.bookmarks) {
        if let Ok(c_str) = CString::new(b_json) {
            unsafe {
                *out_bookmarks = c_str.into_raw();
            }
        }
    }

    if let Ok(h_json) = serde_json::to_string(&sync_result.history) {
        if let Ok(c_str) = CString::new(h_json) {
            unsafe {
                *out_history = c_str.into_raw();
            }
        }
    }
}

extern "C" fn cb_switch_engine(engine: *const c_char, url: *const c_char) {
    if engine.is_null() {
        return;
    }
    let eng_str = unsafe { CStr::from_ptr(engine) }.to_str().unwrap_or("chromium");
    let url_str = if !url.is_null() {
        unsafe { CStr::from_ptr(url) }.to_str().unwrap_or("")
    } else {
        ""
    };

    println!("[OmaBrowser] Engine switch triggered: {} for URL: {}", eng_str, url_str);

    if eng_str == "firefox" {
        println!("[OmaBrowser] Launching Firefox / Zen Browser instance...");
        engines::EngineManager::launch_firefox(url_str);
    }
}

extern "C" fn cb_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

fn main() {
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    println!("     Focus - Minimalist Browser for Omarchy (Rust + Qt6)     ");
    println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    // 1. Load config
    let cfg = config::load_config();
    let config_json = serde_json::to_string(&cfg).unwrap_or_else(|_| "{}".to_string());

    // 2. Load Omarchy theme
    let current_theme = theme::load_omarchy_theme();
    let theme_json = serde_json::to_string(&current_theme).unwrap_or_else(|_| "{}".to_string());
    println!("[Focus] Loaded Omarchy theme: mode={}, accent={}", current_theme.mode, current_theme.accent);

    // 3. Initial sync from Google Chrome / Chromium
    let sync_result = sync::sync_from_chrome_or_chromium();
    let bookmarks_json = serde_json::to_string(&sync_result.bookmarks).unwrap_or_else(|_| "[]".to_string());
    let history_json = serde_json::to_string(&sync_result.history).unwrap_or_else(|_| "[]".to_string());

    if !sync_result.source.is_empty() {
        println!(
            "[Focus] Auto-detected {}: loaded {} bookmarks and {} history entries",
            sync_result.source,
            sync_result.bookmarks.len(),
            sync_result.history.len()
        );
    }

    // 4. Resolve path to ui/main.qml
    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."));

    // Check workspace ui path or installed ui path
    let qml_candidates = [
        PathBuf::from("/mnt/Dados/Projects/Focus/ui/main.qml"),
        PathBuf::from("/mnt/Dados/Projects/omabrowser/ui/main.qml"),
        exe_dir.join("../ui/main.qml"),
        exe_dir.join("ui/main.qml"),
        PathBuf::from("/usr/share/focus/ui/main.qml"),
    ];

    let qml_path = qml_candidates
        .iter()
        .find(|p| p.exists())
        .cloned()
        .unwrap_or_else(|| PathBuf::from("/mnt/Dados/Projects/omabrowser/ui/main.qml"));

    println!("[OmaBrowser] Loading QML from: {}", qml_path.display());

    let c_qml_path = CString::new(qml_path.to_string_lossy().as_bytes()).unwrap();
    let c_theme = CString::new(theme_json).unwrap();
    let c_config = CString::new(config_json).unwrap();
    let c_bookmarks = CString::new(bookmarks_json).unwrap();
    let c_history = CString::new(history_json).unwrap();

    let callbacks = RustCallbacks {
        on_config_saved: cb_config_saved,
        on_chrome_sync: cb_chrome_sync,
        on_switch_engine: cb_switch_engine,
        free_string: cb_free_string,
    };

    // Prepare argv
    let args: Vec<CString> = std::env::args()
        .map(|arg| CString::new(arg).unwrap())
        .collect();
    let mut c_args: Vec<*mut c_char> = args.iter().map(|arg| arg.as_ptr() as *mut c_char).collect();
    let argc = c_args.len() as i32;

    unsafe {
        let code = oma_run_gui(
            argc,
            c_args.as_mut_ptr(),
            c_qml_path.as_ptr(),
            c_theme.as_ptr(),
            c_config.as_ptr(),
            c_bookmarks.as_ptr(),
            c_history.as_ptr(),
            callbacks,
        );
        std::process::exit(code);
    }
}
