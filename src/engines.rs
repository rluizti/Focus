use std::process::Command;

pub struct EngineManager;

impl EngineManager {
    pub fn find_firefox_executable() -> Option<String> {
        let candidates = ["zen-browser", "firefox", "librewolf", "waterfox", "firefox-developer-edition"];
        for cand in &candidates {
            if let Ok(output) = Command::new("which").arg(cand).output() {
                if output.status.success() {
                    let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
                    if !path.is_empty() {
                        return Some(path);
                    }
                }
            }
        }
        None
    }

    pub fn launch_firefox(url: &str) -> bool {
        if let Some(bin) = Self::find_firefox_executable() {
            let target = if url.is_empty() { "https://www.google.com" } else { url };
            let _ = Command::new(bin)
                .arg(target)
                .spawn();
            true
        } else {
            false
        }
    }
}
