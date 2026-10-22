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
                var currentUrl = (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? tabsModel.get(activeTabIndex).url : "";
                var targetUrl = (currentUrl && currentUrl.length > 0 && currentUrl !== "about:blank") ? currentUrl : "https://www.google.com";
                var newId = tabsModel.count + 1;
                tabsModel.append({
                    tabId: newId,
                    title: "",
                    url: targetUrl,
                    workspace: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).workspace || "Principal") : "Principal",
                    favicon: ""
                });
                splitTabIndex = tabsModel.count - 1;
            } else {
                if (splitTabIndex === activeTabIndex) {
                    splitTabIndex = (activeTabIndex + 1) % tabsModel.count;
                }
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
            favicon: ""
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
                property alias webViewItem: webView
                anchors.top: parent.top
                anchors.bottom: devToolsDock.top

                readonly property bool isLeftPane: index === window.activeTabIndex
                readonly property bool isRightPane: window.splitViewActive && index === window.splitTabIndex

                visible: isLeftPane || isRightPane

                // Explicit positioning to guarantee perfect two-pane split with center divider
                x: (!window.splitViewActive || isLeftPane) ? 0 : Math.ceil((parent.width + Theme.borderSize) / 2)
                width: window.splitViewActive ? Math.floor((parent.width - Theme.borderSize) / 2) : parent.width

                // Active focus border in split view
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (window.splitViewActive && ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right"))) ? Theme.accent : "transparent"
                    border.width: 1
                    z: 50
                }

                // Placeholder when tab has no URL loaded yet
                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    visible: !model.url || model.url.length === 0 || model.url === "about:blank"
                    z: 10

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Rectangle {
                            width: 56
                            height: 56
                            radius: 28
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            Glyph {
                                name: "dual"
                                size: 24
                                color: Theme.accent
                                anchors.centerIn: parent
                            }
                        }

                        Text {
                            text: isRightPane ? "Janela Dividida Direita" : "Focus"
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.foreground
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Digite um endereço na barra superior para carregar"
                            font.pixelSize: 12
                            color: Theme.muted
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
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

                    onIconChanged: {
                        var iconStr = icon ? icon.toString() : "";
                        tabsModel.setProperty(index, "favicon", iconStr);
                    }

                    function injectSelectionStyle() {
                        var accentColor = Theme.accent;
                        var bgColor = Theme.background;
                        var js = "(function() {" +
                            "var style = document.getElementById('focus-selection-theme');" +
                            "if (!style) {" +
                            "  style = document.createElement('style');" +
                            "  style.id = 'focus-selection-theme';" +
                            "  (document.head || document.documentElement).appendChild(style);" +
                            "}" +
                            "style.textContent = '::selection { background-color: " + accentColor + " !important; color: " + bgColor + " !important; } " +
                            "::-moz-selection { background-color: " + accentColor + " !important; color: " + bgColor + " !important; }';" +
                            "})();";
                        runJavaScript(js);
                    }

                    Connections {
                        target: Theme
                        function onAccentChanged() {
                            webView.injectSelectionStyle();
                        }
                    }

                    onLoadingChanged: function(loadRequest) {
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            bridge.isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus);
                        }

                        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            webView.injectSelectionStyle();
                        }

                        // Auto fallback: Se falhou ao carregar endereço digitado sem www (DNS/resolução de host falhou), tenta automaticamente com www.
                        if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                            var failedUrl = loadRequest.url ? loadRequest.url.toString() : "";
                            if (failedUrl && failedUrl.startsWith("https://") && !failedUrl.startsWith("https://www.")) {
                                var retryUrl = failedUrl.replace("https://", "https://www.");
                                console.log("[Focus] Host não encontrado sem www, tentando com www: " + retryUrl);
                                webView.url = retryUrl;
                                tabsModel.setProperty(index, "url", retryUrl);
                                if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                                    bridge.currentUrl = retryUrl;
                                }
                            }
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
                var item = tabsRepeater.itemAt(targetIndex);
                if (item && item.webViewItem) {
                    item.webViewItem.url = url;
                }
            }
        }

        onNewTabRequested: function(url, workspace) {
            var newId = tabsModel.count + 1;
            tabsModel.append({
                tabId: newId,
                title: url ? "" : "Nova Aba",
                url: url,
                workspace: workspace,
                favicon: ""
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
                    if (index === window.activeTabIndex && tabsModel.count > 1) {
                        window.activeTabIndex = window.splitTabIndex;
                    }
                    window.splitTabIndex = index;
                } else if (window.splitViewActive && window.focusedPane === "left") {
                    if (index === window.splitTabIndex && tabsModel.count > 1) {
                        window.splitTabIndex = window.activeTabIndex;
                    }
                    window.activeTabIndex = index;
                } else {
                    window.activeTabIndex = index;
                }
                var curIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
                var currentTab = tabsModel.get(curIdx);
                bridge.currentUrl = currentTab ? currentTab.url : "";
                window.activeWebTitle = currentTab ? currentTab.title : "";
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
                tabsModel.setProperty(0, "favicon", "");
                bridge.currentUrl = "";
                window.activeWebTitle = "";
            }
        }

        onWebViewAction: function(action) {
            var targetIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            var activeItem = tabsRepeater.itemAt(targetIdx);
            if (activeItem && activeItem.webViewItem) {
                var ch = activeItem.webViewItem;
                if (action === "back") ch.goBack();
                else if (action === "forward") ch.goForward();
                else if (action === "reload") ch.reload();
                else if (action === "stop") ch.stop();
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
