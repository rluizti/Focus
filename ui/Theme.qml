import QtQuick

pragma Singleton

QtObject {
    id: root

    property var data: {
        try {
            return JSON.parse(bridge.themeJson)
        } catch (e) {
            return {}
        }
    }

    readonly property string mode: root.data.mode || "dark"
    readonly property color background: root.data.background || "#0c0b0c"
    readonly property color surface: root.data.surface || "#121113"
    readonly property color surfaceVariant: root.data.surface_variant || "#1a191c"
    readonly property color foreground: root.data.foreground || "#FAFCFB"
    readonly property color dimForeground: root.data.dim_foreground || "#8f8a8e"
    readonly property color accent: root.data.accent || "#b59790"
    readonly property color border: root.data.border || "#2d2a2c"
    readonly property color selection: root.data.selection || "#383335"
    readonly property color red: root.data.red || "#c38b7b"
    readonly property color green: root.data.green || "#87a9b0"
    readonly property color blue: root.data.blue || "#b59790"
    readonly property string fontFamily: "Inter, monospace, sans-serif"
    
    // Omarchy launcher uses square / straight corners (cantos retos)
    readonly property int cornerRadius: 0

    readonly property int fontBody: 13
    readonly property int fontTitle: 15
    readonly property int fontCaption: 11
}
