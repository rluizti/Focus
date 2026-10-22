fn main() {
    println!("cargo:rerun-if-changed=CMakeLists.txt");
    println!("cargo:rerun-if-changed=src/bridge/bridge.cpp");
    println!("cargo:rerun-if-changed=src/bridge/bridge.h");

    let dst = cmake::Config::new(".")
        .build_target("focusbridge")
        .build();

    println!("cargo:rustc-link-search=native={}/build", dst.display());
    println!("cargo:rustc-link-lib=static=focusbridge");

    // Link Qt6 libraries
    let libs = [
        "Qt6WebEngineQuick",
        "Qt6WebEngineCore",
        "Qt6WebChannel",
        "Qt6Positioning",
        "Qt6WebChannelQuick",
        "Qt6Quick",
        "Qt6OpenGL",
        "Qt6Qml",
        "Qt6Network",
        "Qt6Gui",
        "Qt6Core",
        "stdc++",
    ];

    for lib in &libs {
        println!("cargo:rustc-link-lib={}", lib);
    }
}
