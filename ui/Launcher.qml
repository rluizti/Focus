import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: bridge.launcherVisible
    anchors.fill: parent
    z: 500

    // Backdrop overlay
    Rectangle {
        anchors.fill: parent
        color: "#60000000"
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: bridge.launcherVisible = false
        }
    }

    // Floating Central Launcher Card
    Rectangle {
        id: launcherCard
        width: Math.min(680, parent.width - 40)
        height: inputQuery.text.trim().length > 0 ? Math.min(480, 120 + resultsModel.count * 46) : 110
        anchors.top: parent.top
        anchors.topMargin: root.visible ? 32 : -launcherCard.height
        anchors.horizontalCenter: parent.horizontalCenter

        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.border
        border.width: 1

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Swallowing clicks
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Top Search Input Box
            Item {
                width: parent.width
                height: 58

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    // Engine Icon / Indicator
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 7
                        color: bridge.currentEngine === "chromium" ? Qt.rgba(0.5, 0.7, 1.0, 0.2) : Qt.rgba(1.0, 0.6, 0.3, 0.2)
                        border.color: bridge.currentEngine === "chromium" ? Theme.blue : Theme.red
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: bridge.currentEngine === "chromium" ? "⚡" : "🦊"
                            font.pixelSize: 13
                            anchors.centerIn: parent
                        }
                    }

                    // Main Omnibar Input
                    TextInput {
                        id: inputQuery
                        width: parent.width - 120
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        focus: true
                        selectByMouse: true
                        clip: true

                        Text {
                            text: "Digite uma URL ou pesquise..."
                            color: Theme.dimForeground
                            font.pixelSize: 16
                            font.family: Theme.fontFamily
                            visible: !inputQuery.text && !inputQuery.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: root.filterResults(text)

                        Keys.onReturnPressed: {
                            root.executeAction(inputQuery.text)
                        }

                        Keys.onEscapePressed: {
                            bridge.launcherVisible = false
                        }

                        Component.onCompleted: {
                            if (root.visible) forceActiveFocus()
                        }
                    }

                    // Search Engine Pill
                    Rectangle {
                        height: 24
                        width: 72
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "Google ▾"
                            color: Theme.dimForeground
                            font.pixelSize: 11
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bridge.settingsVisible = true
                        }
                    }
                }

                // Divider below input
                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: Theme.border
                }
            }

            // Results List
            ListView {
                id: resultsList
                width: parent.width
                height: inputQuery.text.trim().length > 0 ? parent.height - 58 - 48 : 0
                clip: true
                visible: height > 0
                model: ListModel { id: resultsModel }

                delegate: Rectangle {
                    width: resultsList.width
                    height: 44
                    color: resMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.navigateTo(model.url)
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12

                        Text {
                            text: model.icon
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 40
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: model.title
                                color: Theme.foreground
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: model.url
                                color: Theme.dimForeground
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }

            // Bottom Quick Actions Bar
            Rectangle {
                width: parent.width
                height: 48
                color: Theme.surfaceVariant

                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.top: parent.top
                    color: Theme.border
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    // Back
                    ActionButton {
                        iconText: "←"
                        tooltip: "Voltar"
                        onClicked: { bridge.launcherVisible = false; webViewAction("back"); }
                    }

                    // Forward
                    ActionButton {
                        iconText: "→"
                        tooltip: "Avançar"
                        onClicked: { bridge.launcherVisible = false; webViewAction("forward"); }
                    }

                    // Reload
                    ActionButton {
                        iconText: "⟳"
                        tooltip: "Recarregar"
                        onClicked: { bridge.launcherVisible = false; webViewAction("reload"); }
                    }

                    // Home
                    ActionButton {
                        iconText: "🏠"
                        tooltip: "Início"
                        onClicked: root.navigateTo("https://www.google.com")
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    spacing: 8

                    // Engine Toggle Button
                    Rectangle {
                        height: 30
                        width: 140
                        radius: 6
                        color: engineMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: bridge.currentEngine === "chromium" ? "⚡ Chromium" : "🦊 Firefox/Zen"
                                color: Theme.foreground
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: engineMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = bridge.currentEngine === "chromium" ? "firefox" : "chromium";
                                bridge.switchEngine(next, bridge.currentUrl);
                            }
                        }
                    }

                    // Chrome Sync Button
                    ActionButton {
                        iconText: "🔄"
                        tooltip: "Sincronizar Google Chrome"
                        onClicked: bridge.syncChrome()
                    }

                    // Settings Button
                    ActionButton {
                        iconText: "⚙️"
                        tooltip: "Configurações"
                        onClicked: {
                            bridge.launcherVisible = false;
                            bridge.settingsVisible = true;
                        }
                    }
                }
            }
        }
    }

    // Helper component for quick action buttons
    component ActionButton: Rectangle {
        property string iconText: ""
        property string tooltip: ""
        signal clicked()

        width: 32
        height: 32
        radius: 6
        color: btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        border.color: btnMouse.containsMouse ? Theme.border : "transparent"
        border.width: 1

        Text {
            text: iconText
            color: Theme.foreground
            font.pixelSize: 14
            anchors.centerIn: parent
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    signal webViewAction(string action)

    function executeAction(text) {
        var query = text.trim();
        if (!query) return;

        var targetUrl = "";
        // Check if URL
        if (query.match(/^(http:\/\/|https:\/\/|file:\/\/)/i)) {
            targetUrl = query;
        } else if (query.indexOf(".") !== -1 && query.indexOf(" ") === -1) {
            targetUrl = "https://" + query;
        } else {
            // Search query with configured engine
            targetUrl = "https://www.google.com/search?q=" + encodeURIComponent(query);
        }

        navigateTo(targetUrl);
    }

    function navigateTo(url) {
        bridge.launcherVisible = false;
        inputQuery.text = "";

        if (bridge.currentEngine === "firefox") {
            bridge.launchFirefox(url);
        } else {
            bridge.currentUrl = url;
        }
    }

    function filterResults(query) {
        resultsModel.clear();
        var q = query.trim().toLowerCase();
        if (!q) return;

        // 1. Direct search suggestion
        var isUrl = q.match(/^(http:\/\/|https:\/\/)/i) || (q.indexOf(".") !== -1 && q.indexOf(" ") === -1);
        resultsModel.append({
            icon: isUrl ? "🌐" : "🔍",
            title: isUrl ? "Abrir URL: " + q : "Pesquisar no Google: \"" + query + "\"",
            url: isUrl ? (q.startsWith("http") ? q : "https://" + q) : ("https://www.google.com/search?q=" + encodeURIComponent(query))
        });

        // 2. Filter Bookmarks from Chrome
        try {
            var bookmarks = JSON.parse(bridge.bookmarksJson || "[]");
            var bCount = 0;
            for (var i = 0; i < bookmarks.length && bCount < 5; i++) {
                var b = bookmarks[i];
                if ((b.title && b.title.toLowerCase().indexOf(q) !== -1) || (b.url && b.url.toLowerCase().indexOf(q) !== -1)) {
                    resultsModel.append({
                        icon: "⭐",
                        title: b.title || b.url,
                        url: b.url
                    });
                    bCount++;
                }
            }
        } catch(e) {}

        // 3. Filter History from Chrome
        try {
            var history = JSON.parse(bridge.historyJson || "[]");
            var hCount = 0;
            for (var j = 0; j < history.length && hCount < 6; j++) {
                var h = history[j];
                if ((h.title && h.title.toLowerCase().indexOf(q) !== -1) || (h.url && h.url.toLowerCase().indexOf(q) !== -1)) {
                    resultsModel.append({
                        icon: "🕒",
                        title: h.title || h.domain,
                        url: h.url
                    });
                    hCount++;
                }
            }
        } catch(e) {}
    }

    Connections {
        target: bridge
        function onLauncherVisibleChanged() {
            if (bridge.launcherVisible) {
                inputQuery.forceActiveFocus();
                inputQuery.selectAll();
            }
        }
    }
}
