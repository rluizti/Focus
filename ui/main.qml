import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: window
    visible: true
    width: 1280
    height: 800
    minimumWidth: 600
    minimumHeight: 400
    title: bridge.pageTitle ? (bridge.pageTitle + " — Focus") : "Focus"
    color: Theme.background

    // WebEngine View
    WebEngineView {
        id: webView
        anchors.fill: parent
        url: bridge.currentUrl

        onUrlChanged: {
            bridge.currentUrl = url.toString()
        }

        onTitleChanged: {
            bridge.pageTitle = title
        }

        onLoadingChanged: function(loadRequest) {
            bridge.isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus)
        }

        profile: WebEngineProfile.defaultProfile
    }

    // Top Loading Progress Bar
    Rectangle {
        id: progressBar
        height: 2
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width * (webView.loadProgress / 100.0)
        color: Theme.accent
        visible: webView.loading
        z: 900

        Behavior on width {
            NumberAnimation { duration: 100 }
        }
    }

    // Top Edge Trigger Zone (Hovering at the very top triggers launcher)
    MouseArea {
        id: topHoverTrigger
        height: 6
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        hoverEnabled: true
        z: 100

        onEntered: {
            bridge.launcherVisible = true
        }
    }

    // Expandable Top Launcher (Summoned with Space or hovering top)
    Launcher {
        id: launcher

        onWebViewAction: function(action) {
            if (action === "back") webView.goBack()
            else if (action === "forward") webView.goForward()
            else if (action === "reload") webView.reload()
        }
    }

    // Settings Modal
    SettingsModal {
        id: settingsModal
    }

    // Global Key Handlers
    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            // Space opens launcher when not inside web input
            if (event.key === Qt.Key_Space && !bridge.launcherVisible && !bridge.settingsVisible) {
                bridge.launcherVisible = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
                bridge.launcherVisible = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Comma && (event.modifiers & Qt.ControlModifier)) {
                bridge.settingsVisible = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                webView.reload();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                if (bridge.settingsVisible) {
                    bridge.settingsVisible = false;
                    event.accepted = true;
                } else if (bridge.launcherVisible) {
                    bridge.launcherVisible = false;
                    event.accepted = true;
                }
            }
        }
    }

    Connections {
        target: bridge
        function onCurrentUrlChanged() {
            if (webView.url.toString() !== bridge.currentUrl) {
                webView.url = bridge.currentUrl;
            }
        }
    }
}
