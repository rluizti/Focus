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
    title: activeWebTitle ? (activeWebTitle + " — Focus") : "Focus"
    color: Theme.background

    // Tabs Model for Multi-tab & Workspace management
    ListModel {
        id: tabsModel
        ListElement {
            tabId: 1
            title: ""
            url: ""  // Inicialmente NADA no fundo (canvas limpo!)
            workspace: "Principal"
        }
    }

    property int activeTabIndex: 0
    property string activeWebTitle: ""

    // Omarchy Canvas Content with Inactive Opacity Effect
    Item {
        id: rootCanvas
        anchors.fill: parent
        opacity: (window.active || rootMouseDetector.containsMouse) ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        // Global Mouse Detection for hover opacity
        MouseArea {
            id: rootMouseDetector
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 0
        }

        // 100% CLEAN USEFUL AREA - Zero overlays on the web canvas
        Repeater {
            id: tabsRepeater
            model: tabsModel

            delegate: Item {
                anchors.fill: parent
                visible: index === window.activeTabIndex

                // WebEngineView só renderiza quando existe uma URL válida
                WebEngineView {
                    id: webView
                    anchors.fill: parent
                    visible: model.url && model.url.length > 0 && model.url !== "about:blank"
                    url: model.url

                onUrlChanged: {
                    if (index === window.activeTabIndex) {
                        bridge.currentUrl = url.toString();
                    }
                    tabsModel.setProperty(index, "url", url.toString());
                }

                onTitleChanged: {
                    if (index === window.activeTabIndex) {
                        window.activeWebTitle = title;
                        bridge.pageTitle = title;
                    }
                    tabsModel.setProperty(index, "title", title);
                }

                onLoadingChanged: function(loadRequest) {
                    if (index === window.activeTabIndex) {
                        bridge.isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus);
                    }
                }
            }
        }
    }
}

    // Top Edge Trigger Zone (Hovering at the extreme top edge reveals the launcher)
    MouseArea {
        id: topHoverTrigger
        height: 4
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        hoverEnabled: true
        z: 100

        onEntered: {
            bridge.launcherVisible = true
        }
    }

    // Expandable Top Launcher - The SOLE point of interaction
    Launcher {
        id: launcher
        tabsModel: tabsModel
        activeTabIndex: window.activeTabIndex

        onOpenUrlInTab: function(url) {
            if (tabsModel.count > 0 && window.activeTabIndex < tabsModel.count) {
                tabsModel.setProperty(window.activeTabIndex, "url", url);
                bridge.currentUrl = url;
            }
        }

        onNewTabRequested: function(url, workspace) {
            var newId = tabsModel.count + 1;
            tabsModel.append({
                tabId: newId,
                title: url ? "" : "Nova Aba",
                url: url,
                workspace: workspace
            });
            window.activeTabIndex = tabsModel.count - 1;
            bridge.currentUrl = url;
        }

        onSwitchTabRequested: function(index) {
            if (index >= 0 && index < tabsModel.count) {
                window.activeTabIndex = index;
                var currentTab = tabsModel.get(index);
                bridge.currentUrl = currentTab.url;
                window.activeWebTitle = currentTab.title;
            }
        }

        onCloseTabRequested: function(index) {
            if (tabsModel.count > 1) {
                tabsModel.remove(index);
                if (window.activeTabIndex >= tabsModel.count) {
                    window.activeTabIndex = tabsModel.count - 1;
                }
                var activeTab = tabsModel.get(window.activeTabIndex);
                bridge.currentUrl = activeTab.url;
                window.activeWebTitle = activeTab.title;
            } else if (tabsModel.count === 1) {
                // If closing last tab, reset to blank
                tabsModel.setProperty(0, "url", "");
                tabsModel.setProperty(0, "title", "");
                bridge.currentUrl = "";
                window.activeWebTitle = "";
            }
        }

        onWebViewAction: function(action) {
            // Forward action to active WebEngineView
            var activeItem = tabsRepeater.itemAt(window.activeTabIndex);
            if (activeItem) {
                var view = activeItem.children[0];
                if (view) {
                    if (action === "back") view.goBack();
                    else if (action === "forward") view.goForward();
                    else if (action === "reload") view.reload();
                }
            }
        }
    }

    // Floating Settings Modal (Estilo Flea SettingsPanel)
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
            } else if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)) {
                launcher.isExpanded = true;
                bridge.launcherVisible = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Comma && (event.modifiers & Qt.ControlModifier)) {
                bridge.settingsVisible = true;
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
            if (tabsModel.count > 0 && window.activeTabIndex < tabsModel.count) {
                var currentTab = tabsModel.get(window.activeTabIndex);
                if (currentTab.url !== bridge.currentUrl && bridge.currentUrl.length > 0) {
                    tabsModel.setProperty(window.activeTabIndex, "url", bridge.currentUrl);
                }
            }
        }
    }
}
