import QtQuick

pragma Singleton

Item {
    id: root

    property string rawTheme: bridge.themeJson
    property string rawConfig: bridge.configJson

    property var data: {
        try {
            return JSON.parse(bridge.themeJson)
        } catch (e) {
            return {}
        }
    }

    property var config: {
        try {
            return JSON.parse(bridge.configJson)
        } catch (e) {
            return {}
        }
    }

    Connections {
        target: bridge
        function onThemeJsonChanged() {
            root.rawTheme = bridge.themeJson;
            try {
                root.data = JSON.parse(bridge.themeJson);
            } catch (e) {
                root.data = {};
            }
        }
        function onConfigJsonChanged() {
            root.rawConfig = bridge.configJson;
            try {
                root.config = JSON.parse(bridge.configJson);
            } catch (e) {
                root.config = {};
            }
        }
    }

    // "system" (Omarchy system theme), "dark" (force dark), "light" (force light)
    readonly property string themePreference: (root.config && root.config.theme_mode) ? root.config.theme_mode : "system"

    readonly property bool isLightMode: {
        if (themePreference === "light") return true;
        if (themePreference === "dark") return false;
        return (root.data && root.data.mode === "light");
    }

    readonly property string mode: isLightMode ? "light" : "dark"

    readonly property color background: {
        if (themePreference === "system") return (root.data && root.data.background) ? root.data.background : "#0c0b0c";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.background) ? root.data.background : "#f7f7f9";
        }
        return (root.data && root.data.mode === "dark" && root.data.background) ? root.data.background : "#0c0b0c";
    }

    readonly property color surface: {
        if (themePreference === "system") return (root.data && root.data.surface) ? root.data.surface : "#121113";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.surface) ? root.data.surface : "#ffffff";
        }
        return (root.data && root.data.mode === "dark" && root.data.surface) ? root.data.surface : "#121113";
    }

    readonly property color surfaceVariant: {
        if (themePreference === "system") return (root.data && root.data.surface_variant) ? root.data.surface_variant : "#1a191c";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.surface_variant) ? root.data.surface_variant : "#eeeff2";
        }
        return (root.data && root.data.mode === "dark" && root.data.surface_variant) ? root.data.surface_variant : "#1a191c";
    }

    readonly property color foreground: {
        if (themePreference === "system") return (root.data && root.data.foreground) ? root.data.foreground : "#FAFCFB";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.foreground) ? root.data.foreground : "#1a1a1c";
        }
        return (root.data && root.data.mode === "dark" && root.data.foreground) ? root.data.foreground : "#FAFCFB";
    }

    readonly property color dimForeground: {
        if (themePreference === "system") return (root.data && root.data.dim_foreground) ? root.data.dim_foreground : "#8f8a8e";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.dim_foreground) ? root.data.dim_foreground : "#6e6d72";
        }
        return (root.data && root.data.mode === "dark" && root.data.dim_foreground) ? root.data.dim_foreground : "#8f8a8e";
    }

    readonly property color muted: dimForeground

    readonly property color accent: (root.data && root.data.accent) ? root.data.accent : (isLightMode ? "#2f6feb" : "#b59790")

    readonly property color border: {
        if (themePreference === "system") return (root.data && root.data.border) ? root.data.border : "#2d2a2c";
        if (themePreference === "light") {
            return (root.data && root.data.mode === "light" && root.data.border) ? root.data.border : "#d3d2d6";
        }
        return (root.data && root.data.mode === "dark" && root.data.border) ? root.data.border : "#2d2a2c";
    }

    // O contorno ativo do lançador e janelas acompanha o acento do tema do sistema (Theme.accent)
    readonly property color activeBorder: accent
    readonly property int borderSize: (root.data && root.data.border_size !== undefined) ? root.data.border_size : 2

    readonly property color selection: {
        if (themePreference === "system") return root.data.selection || "#383335";
        if (themePreference === "light") {
            return (root.data.mode === "light" && root.data.selection) ? root.data.selection : "#e2e1e6";
        }
        return (root.data.mode === "dark" && root.data.selection) ? root.data.selection : "#383335";
    }

    readonly property color red: root.data.red || "#c38b7b"
    readonly property color green: root.data.green || "#87a9b0"
    readonly property color blue: root.data.blue || "#b59790"
    readonly property string fontFamily: "Inter, 'Liberation Sans', sans-serif"
    
    // Follows Omarchy theme rounding (0 for sharp themes, 6/8/12 for rounded themes)
    readonly property int cornerRadius: (root.data.corner_radius !== undefined && root.data.corner_radius !== null) ? root.data.corner_radius : 8

    readonly property int fontBody: 13
    readonly property int fontTitle: 15
    readonly property int fontCaption: 11
}
