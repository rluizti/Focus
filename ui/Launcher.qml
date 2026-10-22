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
        color: "#75000000"
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: bridge.launcherVisible = false
        }
    }

    // Workspaces and Tabs State
    property var workspaces: ["Principal", "Trabalho", "Pessoal"]
    property string activeWorkspace: "Principal"
    property bool tabsDrawerOpen: false

    // Pinned Sites (Zen Browser Style - 2 rows)
    property var pinnedRow1: [
        { name: "Google", url: "https://www.google.com", icon: "🌐" },
        { name: "YouTube", url: "https://www.youtube.com", icon: "▶" },
        { name: "GitHub", url: "https://github.com", icon: "🐙" },
        { name: "Gmail", url: "https://mail.google.com", icon: "✉" },
        { name: "Reddit", url: "https://reddit.com", icon: "🤖" },
        { name: "X", url: "https://x.com", icon: "𝕏" }
    ]

    property var pinnedRow2: [
        { name: "ChatGPT", url: "https://chatgpt.com", icon: "💬" },
        { name: "Claude", url: "https://claude.ai", icon: "✦" },
        { name: "Spotify", url: "https://open.spotify.com", icon: "♫" },
        { name: "Twitch", url: "https://twitch.tv", icon: "🎮" },
        { name: "Maps", url: "https://maps.google.com", icon: "🗺" },
        { name: "Tradutor", url: "https://translate.google.com", icon: "文" }
    ]

    // Floating Central Launcher Card - Square corners (cantos retos) following Omarchy
    Rectangle {
        id: launcherCard
        width: Math.min(680, parent.width - 48)
        anchors.top: parent.top
        anchors.topMargin: root.visible ? 40 : -launcherCard.height
        anchors.horizontalCenter: parent.horizontalCenter

        color: Theme.surface
        radius: 0 // Cantos retos
        border.color: Theme.border
        border.width: 1

        // Dynamic height based on typing state and tabs drawer
        height: {
            var isTyping = inputQuery.text.trim().length > 0;
            if (isTyping) {
                // Expanded search results
                return Math.min(480, 52 + resultsModel.count * 44);
            } else if (root.tabsDrawerOpen) {
                // Input + Pinned rows + Tabs Drawer + Bottom Bar
                return 52 + 104 + 160 + 44;
            } else {
                // Input box + 2 rows of pinned sites
                return 52 + 104;
            }
        }

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Swallowing clicks
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // 1. TOP TYPING INPUT BAR (Clean, square, Omarchy style)
            Rectangle {
                width: parent.width
                height: 52
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
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    // Search Engine / Mode Icon
                    Text {
                        text: bridge.currentEngine === "chromium" ? "⚡" : "🦊"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Main Text Input
                    TextInput {
                        id: inputQuery
                        width: parent.width - 110
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        focus: true
                        selectByMouse: true
                        clip: true

                        Text {
                            text: "Digite uma URL ou pesquise..."
                            color: Theme.dimForeground
                            font.pixelSize: 14
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

                    // Corner Icon: Toggle Tabs & Workspaces
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 0
                        color: root.tabsDrawerOpen ? Theme.selection : (tabIconMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: root.tabsDrawerOpen ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "🗂"
                            font.pixelSize: 14
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: tabIconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.tabsDrawerOpen = !root.tabsDrawerOpen;
                            }
                        }
                    }
                }
            }

            // 2. PINNED SITES (Estilo Zen Browser - 2 linhas)
            // Visível quando o usuário NÃO está digitando busca
            Item {
                id: pinnedSection
                width: parent.width
                height: 104
                visible: inputQuery.text.trim().length === 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Linha 1 de páginas pinadas
                    Row {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: root.pinnedRow1

                            Rectangle {
                                width: (launcherCard.width - 20 - 40) / 6
                                height: 38
                                radius: 0 // Cantos retos
                                color: pin1Mouse.containsMouse ? Theme.selection : Qt.rgba(1, 1, 1, 0.03)
                                border.color: pin1Mouse.containsMouse ? Theme.accent : Theme.border
                                border.width: 1

                                MouseArea {
                                    id: pin1Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.navigateTo(modelData.url)
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        color: Theme.foreground
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Linha 2 de páginas pinadas
                    Row {
                        spacing: 8
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: root.pinnedRow2

                            Rectangle {
                                width: (launcherCard.width - 20 - 40) / 6
                                height: 38
                                radius: 0 // Cantos retos
                                color: pin2Mouse.containsMouse ? Theme.selection : Qt.rgba(1, 1, 1, 0.03)
                                border.color: pin2Mouse.containsMouse ? Theme.accent : Theme.border
                                border.width: 1

                                MouseArea {
                                    id: pin2Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.navigateTo(modelData.url)
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.name
                                        color: Theme.foreground
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: Theme.border
                    visible: root.tabsDrawerOpen
                }
            }

            // 3. SEARCH SUGGESTIONS (Aparece SOMENTE ao digitar)
            ListView {
                id: resultsList
                width: parent.width
                height: inputQuery.text.trim().length > 0 ? (launcherCard.height - 52) : 0
                clip: true
                visible: inputQuery.text.trim().length > 0
                model: ListModel { id: resultsModel }

                delegate: Rectangle {
                    width: resultsList.width
                    height: 44
                    radius: 0
                    color: resMouse.containsMouse ? Theme.selection : "transparent"

                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateTo(model.url)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: model.icon
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 36
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: model.title
                                color: Theme.foreground
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: model.url
                                color: Theme.dimForeground
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }

            // 4. ABAS E ESPAÇOS DE TRABALHO (Abre ao clicar no ícone do cantinho)
            Item {
                id: tabsSection
                width: parent.width
                height: 160
                visible: root.tabsDrawerOpen && inputQuery.text.trim().length === 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Workspaces Bar (Grupos em Espaços de Trabalho Separados)
                    Row {
                        spacing: 8
                        width: parent.width

                        Repeater {
                            model: root.workspaces

                            Rectangle {
                                height: 26
                                width: 85
                                radius: 0
                                color: root.activeWorkspace === modelData ? Theme.selection : "transparent"
                                border.color: root.activeWorkspace === modelData ? Theme.accent : Theme.border
                                border.width: 1

                                Text {
                                    text: modelData
                                    color: root.activeWorkspace === modelData ? Theme.foreground : Theme.dimForeground
                                    font.pixelSize: 11
                                    font.bold: root.activeWorkspace === modelData
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeWorkspace = modelData
                                }
                            }
                        }

                        // Novo Grupo / Workspace
                        Rectangle {
                            height: 26
                            width: 80
                            radius: 0
                            color: "transparent"
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                text: "+ Grupo"
                                color: Theme.dimForeground
                                font.pixelSize: 11
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var nextId = root.workspaces.length + 1;
                                    var list = root.workspaces.slice();
                                    list.push("Grupo " + nextId);
                                    root.workspaces = list;
                                    root.activeWorkspace = "Grupo " + nextId;
                                }
                            }
                        }
                    }

                    // Tabs List for Active Workspace
                    ListView {
                        id: tabsList
                        width: parent.width
                        height: 100
                        clip: true
                        model: root.tabsModel

                        delegate: Rectangle {
                            width: tabsList.width
                            height: 32
                            radius: 0
                            visible: model.workspace === root.activeWorkspace
                            color: root.activeTabIndex === index ? Theme.selection : (tabRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                            border.color: root.activeTabIndex === index ? Theme.accent : "transparent"
                            border.width: 1

                            MouseArea {
                                id: tabRowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.switchTab(index);
                                    bridge.launcherVisible = false;
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: "📄"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: model.title || model.url
                                    color: Theme.foreground
                                    font.pixelSize: 12
                                    font.bold: root.activeTabIndex === index
                                    elide: Text.ElideRight
                                    width: parent.width - 45
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Fechar Aba
                                Text {
                                    text: "✕"
                                    color: Theme.dimForeground
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeTab(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 5. LINHA INFERIOR COM CONFIGURAÇÕES E BOTÃO DE LOGIN GOOGLE
            // Só abre junto com o drawer de abas abertas conforme solicitado!
            Rectangle {
                id: bottomQuickBar
                width: parent.width
                height: 44
                color: Theme.surfaceVariant
                visible: root.tabsDrawerOpen && inputQuery.text.trim().length === 0

                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.top: parent.top
                    color: Theme.border
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    spacing: 8

                    // Botão Login Google na Barra de Acesso Rápido
                    Rectangle {
                        height: 28
                        width: 120
                        radius: 0
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "🔐"
                                font.pixelSize: 11
                            }

                            Text {
                                text: "Login Google"
                                color: Theme.background
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bridge.launcherVisible = false;
                                root.navigateTo("https://accounts.google.com");
                            }
                        }
                    }

                    // Nova Aba no Grupo Atual
                    Rectangle {
                        height: 28
                        width: 85
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "+ Nova Aba"
                            color: Theme.foreground
                            font.pixelSize: 11
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.createNewTab("https://www.google.com")
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    spacing: 8

                    // Alternador de Motor
                    Rectangle {
                        height: 28
                        width: 120
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: bridge.currentEngine === "chromium" ? "⚡ Chromium" : "🦊 Firefox/Zen"
                            color: Theme.foreground
                            font.pixelSize: 11
                            font.bold: true
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = bridge.currentEngine === "chromium" ? "firefox" : "chromium";
                                bridge.switchEngine(next, bridge.currentUrl);
                            }
                        }
                    }

                    // Sincronizar Chrome
                    Rectangle {
                        height: 28
                        width: 32
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "🔄"
                            font.pixelSize: 12
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bridge.syncChrome()
                        }
                    }

                    // Botão de Configurações
                    Rectangle {
                        height: 28
                        width: 32
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "⚙"
                            color: Theme.foreground
                            font.pixelSize: 13
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bridge.launcherVisible = false;
                                bridge.settingsVisible = true;
                            }
                        }
                    }
                }
            }
        }
    }

    // Signals and tab management functions exposed to main.qml
    property var tabsModel: null
    property int activeTabIndex: 0

    signal openUrlInTab(string url)
    signal newTabRequested(string url, string workspace)
    signal switchTabRequested(int index)
    signal closeTabRequested(int index)

    function executeAction(text) {
        var query = text.trim();
        if (!query) return;

        var targetUrl = "";
        if (query.match(/^(http:\/\/|https:\/\/|file:\/\/)/i)) {
            targetUrl = query;
        } else if (query.indexOf(".") !== -1 && query.indexOf(" ") === -1) {
            targetUrl = "https://" + query;
        } else {
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
            openUrlInTab(url);
        }
    }

    function createNewTab(url) {
        newTabRequested(url, root.activeWorkspace);
        bridge.launcherVisible = false;
        inputQuery.text = "";
    }

    function switchTab(index) {
        switchTabRequested(index);
    }

    function closeTab(index) {
        closeTabRequested(index);
    }

    function filterResults(query) {
        resultsModel.clear();
        var q = query.trim().toLowerCase();
        if (!q) return;

        // 1. Direct search or URL suggestion
        var isUrl = q.match(/^(http:\/\/|https:\/\/)/i) || (q.indexOf(".") !== -1 && q.indexOf(" ") === -1);
        resultsModel.append({
            icon: isUrl ? "🌐" : "🔍",
            title: isUrl ? "Ir para: " + q : "Pesquisar: \"" + query + "\"",
            url: isUrl ? (q.startsWith("http") ? q : "https://" + q) : ("https://www.google.com/search?q=" + encodeURIComponent(query))
        });

        // 2. Bookmarks from Chrome
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

        // 3. History from Chrome
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
            } else {
                root.tabsDrawerOpen = false;
            }
        }
    }
}
