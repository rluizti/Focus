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
    readonly property color surface: root.data.surface || "#141315"
    readonly property color surfaceVariant: root.data.surface_variant || "#1f1d21"
    readonly property color foreground: root.data.foreground || "#FAFCFB"
    readonly property color dimForeground: root.data.dim_foreground || "#8f8a8e"
    readonly property color accent: root.data.accent || "#b59790"
    readonly property color border: root.data.border || "#3a3437"
    readonly property color selection: root.data.selection || "#584e51"
    readonly property color red: root.data.red || "#c38b7b"
    readonly property color green: root.data.green || "#87a9b0"
    readonly property color blue: root.data.blue || "#b59790"
    readonly property string fontFamily: root.data.font_family || "Inter, sans-serif"
    readonly property int cornerRadius: root.data.corner_radius || 12

    readonly property int fontBody: 14
    readonly property int fontTitle: 16
    readonly property int fontCaption: 12
}
