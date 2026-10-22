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
            onClicked: {
                bridge.launcherVisible = false;
                root.isExpanded = false;
            }
        }
    }

    // Workspaces and Tabs State
    property var workspaces: ["Principal", "Trabalho", "Pessoal"]
    property string activeWorkspace: "Principal"
    // Pinned rows only appear when user clicks to expand the box
    property bool isExpanded: false
    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    // Pinned Sites (Zen Browser Style - 2 rows with Omarchy vector icons)
    property var pinnedRow1: [
        { name: "Google", url: "https://www.google.com", glyph: "globe" },
        { name: "YouTube", url: "https://www.youtube.com", glyph: "film" },
        { name: "GitHub", url: "https://github.com", glyph: "code" },
        { name: "Gmail", url: "https://mail.google.com", glyph: "file-text" },
        { name: "Reddit", url: "https://reddit.com", glyph: "globe" },
        { name: "X", url: "https://x.com", glyph: "globe" }
    ]

    property var pinnedRow2: [
        { name: "ChatGPT", url: "https://chatgpt.com", glyph: "terminal" },
        { name: "Claude", url: "https://claude.ai", glyph: "code" },
        { name: "Spotify", url: "https://open.spotify.com", glyph: "music" },
        { name: "Twitch", url: "https://twitch.tv", glyph: "film" },
        { name: "Maps", url: "https://maps.google.com", glyph: "pointer" },
        { name: "Tradutor", url: "https://translate.google.com", glyph: "type" }
    ]

    // Floating Central Launcher Card - Single unified box with Omarchy contour & corner radius
    Rectangle {
        id: launcherCard
        width: Math.min(680, parent.width - 48)
        anchors.top: parent.top
        anchors.topMargin: root.visible ? 36 : -launcherCard.height
        anchors.horizontalCenter: parent.horizontalCenter

        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.activeBorder
        border.width: Theme.borderSize
        clip: true

        // Dynamic height:
        // 1. Typing: expands to fit search results
        // 2. Expanded (user clicked expand): input + 2 rows pinned + workspaces/tabs + bottom quick bar
        // 3. Resting: ONLY typing input box (50px)!
        height: {
            var isTyping = inputQuery.text.trim().length > 0;
            if (isTyping) {
                return Math.min(460, 50 + resultsModel.count * 42);
            } else if (root.isExpanded) {
                // Input (50) + Pinned 2 rows (94) + Tabs (140) + Bottom bar (42) = 326px
                return 50 + 94 + 140 + 42;
            } else {
                // Starts ONLY showing the input area
                return 50;
            }
        }

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
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

            // 1. TOP TYPING INPUT BAR (Clean, Omarchy style)
            Rectangle {
                width: parent.width
                height: 50
                color: "transparent"

                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: Theme.border
                    visible: root.isExpanded || inputQuery.text.trim().length > 0
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    // Search Icon (Omarchy Vector Glyph)
                    Glyph {
                        name: "search"
                        size: 15
                        color: Theme.dimForeground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Main Text Input
                    TextInput {
                        id: inputQuery
                        width: parent.width - 90
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        focus: true
                        selectByMouse: true
                        clip: true

                        Text {
                            text: "Digite uma URL ou pesquise..."
                            color: Theme.dimForeground
                            font.pixelSize: 13
                            font.family: Theme.fontFamily
                            visible: !inputQuery.text && !inputQuery.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: root.filterResults(text)

                        Keys.onReturnPressed: {
                            root.executeAction(inputQuery.text)
                        }

                        Keys.onEscapePressed: {
                            if (root.isExpanded) {
                                root.isExpanded = false;
                            } else {
                                bridge.launcherVisible = false;
                            }
                        }

                        Component.onCompleted: {
                            if (root.visible) forceActiveFocus()
                        }
                    }

                    // Corner Expand Button (Toggles Pinned Sites, Tabs & Quick Actions)
                    Rectangle {
                        width: 30
                        height: 30
                        radius: root.itemRadius
                        color: root.isExpanded ? Theme.selection : (expandMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: root.isExpanded ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "tabs"
                            size: 14
                            color: root.isExpanded ? Theme.accent : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: expandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isExpanded = !root.isExpanded;
                            }
                        }
                    }
                }
            }

            // 2. PINNED SITES (Estilo Zen Browser - 2 linhas)
            // SÓ APARECE QUANDO O USUÁRIO CLICA PARA EXPANDIR A CAIXA!
            Item {
                id: pinnedSection
                width: parent.width
                height: 94
                visible: root.isExpanded && inputQuery.text.trim().length === 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // Linha 1 de páginas pinadas
                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: root.pinnedRow1

                            Rectangle {
                                width: (launcherCard.width - 16 - 30) / 6
                                height: 35
                                radius: root.itemRadius // Cantos retos
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

                                    Glyph {
                                        name: modelData.glyph
                                        size: 13
                                        color: pin1Mouse.containsMouse ? Theme.accent : Theme.dimForeground
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
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Repeater {
                            model: root.pinnedRow2

                            Rectangle {
                                width: (launcherCard.width - 16 - 30) / 6
                                height: 35
                                radius: root.itemRadius // Cantos retos
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

                                    Glyph {
                                        name: modelData.glyph
                                        size: 13
                                        color: pin2Mouse.containsMouse ? Theme.accent : Theme.dimForeground
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
                }
            }

            // 3. SEARCH SUGGESTIONS (Aparece SOMENTE ao digitar)
            ListView {
                id: resultsList
                width: parent.width
                height: inputQuery.text.trim().length > 0 ? (launcherCard.height - 50) : 0
                clip: true
                visible: inputQuery.text.trim().length > 0
                model: ListModel { id: resultsModel }

                delegate: Rectangle {
                    width: resultsList.width
                    height: 42
                    radius: root.itemRadius
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

                        Glyph {
                            name: model.isUrl ? "globe" : "search"
                            size: 14
                            color: Theme.accent
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

            // 4. ABAS E ESPAÇOS DE TRABALHO (Aparece quando a caixa está expandida)
            Item {
                id: tabsSection
                width: parent.width
                height: 140
                visible: root.isExpanded && inputQuery.text.trim().length === 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Workspaces Bar (Grupos em Espaços de Trabalho Separados)
                    Row {
                        spacing: 6
                        width: parent.width

                        Repeater {
                            model: root.workspaces

                            Rectangle {
                                height: 25
                                width: 85
                                radius: root.itemRadius
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
                            height: 25
                            width: 75
                            radius: root.itemRadius
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
                        height: 85
                        clip: true
                        model: root.tabsModel

                        delegate: Rectangle {
                            width: tabsList.width
                            height: 30
                            radius: root.itemRadius
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

                                Glyph {
                                    name: "file"
                                    size: 12
                                    color: Theme.dimForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: model.title ? model.title : (model.url ? model.url : "Nova Aba Vazia")
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
            // Só aparece quando a caixa está expandida!
            Rectangle {
                id: bottomQuickBar
                width: parent.width
                height: 42
                color: "transparent"
                visible: root.isExpanded && inputQuery.text.trim().length === 0

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
                        height: 26
                        width: 120
                        radius: root.itemRadius
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Glyph {
                                name: "lock"
                                size: 12
                                color: Theme.background
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Login Google"
                                color: Theme.background
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
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
                        height: 26
                        width: 85
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Glyph { name: "plus"; size: 10; color: Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Nova Aba"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.createNewTab("")
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    spacing: 8

                    // Botão Voltar
                    Rectangle {
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "arrow-left"; size: 12; color: Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { bridge.launcherVisible = false; webViewAction("back"); }
                        }
                    }

                    // Botão Avançar
                    Rectangle {
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "arrow-right"; size: 12; color: Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { bridge.launcherVisible = false; webViewAction("forward"); }
                        }
                    }

                    // Botão Recarregar
                    Rectangle {
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "refresh"; size: 12; color: Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { bridge.launcherVisible = false; webViewAction("reload"); }
                        }
                    }

                    // Sincronizar Chrome
                    Rectangle {
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "history"; size: 12; color: Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bridge.syncChrome()
                        }
                    }

                    // Botão de Configurações
                    Rectangle {
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "settings"; size: 13; color: Theme.foreground; anchors.centerIn: parent }

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
    signal webViewAction(string action)

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
        root.isExpanded = false;
        inputQuery.text = "";

        // Focus IS the browser: Always loads directly inside native WebEngineView!
        openUrlInTab(url);
    }

    function createNewTab(url) {
        newTabRequested(url, root.activeWorkspace);
        bridge.launcherVisible = false;
        root.isExpanded = false;
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
            isUrl: isUrl,
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
                        isUrl: true,
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
                        isUrl: true,
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
                root.isExpanded = false;
            }
        }
    }
}
