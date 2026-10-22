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

    property bool devToolsOpen: false
    property int activeTabIndex: 0
    property string activeWebTitle: ""
    property bool splitViewActive: false
    property int splitTabIndex: 1
    property string focusedPane: "left" // "left" or "right"

    function toggleSplitView() {
        if (!splitViewActive) {
            splitViewActive = true;
            if (tabsModel.count < 2) {
                var newId = tabsModel.count + 1;
                tabsModel.append({
                    tabId: newId,
                    title: "",
                    url: "",
                    workspace: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).workspace || "Principal") : "Principal"
                });
                splitTabIndex = tabsModel.count - 1;
            } else {
                splitTabIndex = (activeTabIndex + 1) % tabsModel.count;
            }
            focusedPane = "right";
            var currentTab = tabsModel.get(splitTabIndex);
            bridge.currentUrl = currentTab ? currentTab.url : "";
            launcher.isExpanded = false;
            bridge.launcherVisible = true;
        } else {
            splitViewActive = false;
            focusedPane = "left";
            var curTab = tabsModel.get(activeTabIndex);
            bridge.currentUrl = curTab ? curTab.url : "";
        }
    }

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

        // 100% CLEAN USEFUL AREA - Zero overlays on the web canvas (Single or Split View)
        Repeater {
            id: tabsRepeater
            model: tabsModel

            delegate: Item {
                id: tabItemDelegate
                anchors.top: parent.top
                anchors.bottom: devToolsDock.top

                readonly property bool isLeftPane: index === window.activeTabIndex
                readonly property bool isRightPane: window.splitViewActive && index === window.splitTabIndex

                visible: isLeftPane || isRightPane

                // Dynamic width and positioning for split screen vs full screen
                anchors.left: (!window.splitViewActive || isLeftPane) ? parent.left : undefined
                anchors.right: (!window.splitViewActive || isRightPane) ? parent.right : undefined
                width: window.splitViewActive ? ((parent.width - Theme.borderSize) / 2) : parent.width

                // Active focus border in split view
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (window.splitViewActive && ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right"))) ? Theme.accent : "transparent"
                    border.width: 1
                    z: 50
                }

                MouseArea {
                    anchors.fill: parent
                    z: 40
                    acceptedButtons: Qt.LeftButton
                    propagateComposedEvents: true
                    onPressed: function(mouse) {
                        if (isLeftPane) {
                            window.focusedPane = "left";
                            bridge.currentUrl = model.url;
                            window.activeWebTitle = model.title;
                        } else if (isRightPane) {
                            window.focusedPane = "right";
                            bridge.currentUrl = model.url;
                            window.activeWebTitle = model.title;
                        }
                        mouse.accepted = false;
                    }
                }

                // WebEngineView só renderiza quando existe uma URL válida
                WebEngineView {
                    id: webView
                    anchors.fill: parent
                    visible: model.url && model.url.length > 0 && model.url !== "about:blank"
                    url: model.url
                    devToolsView: (window.devToolsOpen && ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right"))) ? devToolsView : null

                    onUrlChanged: {
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            bridge.currentUrl = url.toString();
                        }
                        tabsModel.setProperty(index, "url", url.toString());
                    }

                    onTitleChanged: {
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            window.activeWebTitle = title;
                            bridge.pageTitle = title;
                        }
                        tabsModel.setProperty(index, "title", title);
                    }

                    onLoadingChanged: function(loadRequest) {
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            bridge.isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus);
                        }
                    }

                    onContextMenuRequested: function(request) {
                        request.accepted = true;
                        var pos = mapToItem(rootCanvas, request.position.x, request.position.y);
                        contextMenu.showAt(request, webView, pos);
                    }
                }
            }
        }

        // Vertical Divider for Split View
        Rectangle {
            id: splitDivider
            width: Theme.borderSize
            anchors.top: parent.top
            anchors.bottom: devToolsDock.top
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.border
            visible: window.splitViewActive
            z: 60
        }

        // Chrome DevTools Bottom Dock Panel (F12)
        Rectangle {
            id: devToolsDock
            width: parent.width
            height: window.devToolsOpen ? 320 : 0
            anchors.bottom: parent.bottom
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            visible: height > 0
            clip: true
            z: 80

            Behavior on height {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.fill: parent

                // DevTools Header Bar
                Rectangle {
                    width: parent.width
                    height: 28
                    color: Theme.surfaceVariant

                    Rectangle {
                        width: parent.width
                        height: 1
                        anchors.bottom: parent.bottom
                        color: Theme.border
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 8

                        Glyph {
                            name: "terminal"
                            size: 13
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Developer Tools (F12)"
                            color: Theme.foreground
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: dtCloseMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                        Text {
                            text: "✕"
                            color: Theme.dimForeground
                            font.pixelSize: 11
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: dtCloseMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.devToolsOpen = false
                        }
                    }
                }

                // Chrome DevTools Inspector View
                WebEngineView {
                    id: devToolsView
                    width: parent.width
                    height: Math.max(0, parent.height - 28)
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
        activeTabIndex: (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex

        onFlipSplitRequested: window.toggleSplitView()

        onOpenUrlInTab: function(url) {
            var targetIndex = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            if (tabsModel.count > 0 && targetIndex < tabsModel.count) {
                tabsModel.setProperty(targetIndex, "url", url);
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
            if (window.splitViewActive && window.focusedPane === "right") {
                window.splitTabIndex = tabsModel.count - 1;
            } else {
                window.activeTabIndex = tabsModel.count - 1;
            }
            bridge.currentUrl = url;
        }

        onSwitchTabRequested: function(index) {
            if (index >= 0 && index < tabsModel.count) {
                if (window.splitViewActive && window.focusedPane === "right") {
                    window.splitTabIndex = index;
                } else {
                    window.activeTabIndex = index;
                }
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
                if (window.splitTabIndex >= tabsModel.count) {
                    window.splitTabIndex = Math.max(0, tabsModel.count - 1);
                }
                var activeTab = tabsModel.get(window.activeTabIndex);
                bridge.currentUrl = activeTab.url;
                window.activeWebTitle = activeTab.title;
            } else if (tabsModel.count === 1) {
                tabsModel.setProperty(0, "url", "");
                tabsModel.setProperty(0, "title", "");
                bridge.currentUrl = "";
                window.activeWebTitle = "";
            }
        }

        onWebViewAction: function(action) {
            var targetIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            var activeItem = tabsRepeater.itemAt(targetIdx);
            if (activeItem) {
                for (var i = 0; i < activeItem.children.length; i++) {
                    var ch = activeItem.children[i];
                    if (ch && ch.toString().indexOf("QQuickWebEngineView") !== -1) {
                        if (action === "back") ch.goBack();
                        else if (action === "forward") ch.goForward();
                        else if (action === "reload") ch.reload();
                        else if (action === "stop") ch.stop();
                        break;
                    }
                }
            }
        }
    }

    // Floating Settings Modal (Estilo Flea SettingsPanel)
    SettingsModal {
        id: settingsModal
    }

    // Omarchy-Themed Context Menu
    ContextMenu {
        id: contextMenu
    }

    // Global Window Shortcuts (Active window-wide, always intercepts regardless of webView focus)
    Shortcut {
        sequence: "Space"
        enabled: !bridge.launcherVisible && !bridge.settingsVisible
        onActivated: bridge.launcherVisible = true
    }

    Shortcut {
        sequence: "Alt+Space"
        onActivated: bridge.launcherVisible = !bridge.launcherVisible
    }

    Shortcut {
        sequence: "Ctrl+Space"
        onActivated: bridge.launcherVisible = !bridge.launcherVisible
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: bridge.launcherVisible = true
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: {
            launcher.createNewTab("");
            launcher.isExpanded = true;
            bridge.launcherVisible = true;
        }
    }

    Shortcut {
        sequence: "F12"
        onActivated: window.devToolsOpen = !window.devToolsOpen
    }

    Shortcut {
        sequence: "Ctrl+,"
        onActivated: bridge.settingsVisible = true
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: launcher.webViewAction("reload")
    }

    Shortcut {
        sequence: "F5"
        onActivated: launcher.webViewAction("reload")
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (contextMenu.visible) {
                contextMenu.dismiss();
            } else if (window.devToolsOpen) {
                window.devToolsOpen = false;
            } else if (bridge.settingsVisible) {
                bridge.settingsVisible = false;
            } else if (bridge.launcherVisible) {
                launcher.isExpanded = false;
                bridge.launcherVisible = false;
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
