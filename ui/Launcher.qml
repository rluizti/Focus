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

    property var cardConfig: {
        try {
            return JSON.parse(bridge.configJson)
        } catch(e) {
            return { enable_translation: true }
        }
    }

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
            if (root.isExpanded) {
                // Expande completamente mesmo se estiver digitando!
                // Input (50) + Pinned 2 rows (94) + Tabs (140) + Bottom bar (42) = 326px
                return 50 + 94 + 140 + 42;
            } else if (inputQuery.text.trim().length > 0) {
                return Math.min(460, 50 + resultsModel.count * 42);
            } else {
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
            onClicked: {
                if (siteInfoPopup.visible) siteInfoPopup.visible = false;
            }
        }

        // Site Configuration & Security Popup (Page Settings)
        Rectangle {
            id: siteInfoPopup
            width: 290
            height: 185
            anchors.top: parent.top
            anchors.topMargin: 52
            anchors.left: parent.left
            anchors.leftMargin: 10
            radius: root.itemRadius
            color: Theme.surface
            border.color: Theme.activeBorder
            border.width: Theme.borderSize
            visible: false
            z: 999

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Row {
                    spacing: 8
                    Glyph {
                        name: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? "lock" : "alert"
                        size: 16
                        color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Theme.green : Theme.red
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        Text {
                            text: root.extractDomain(bridge.currentUrl) || "Informações da Página"
                            color: Theme.foreground
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Text {
                            text: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? "Conexão segura (HTTPS)" : "Conexão não criptografada"
                            color: Theme.dimForeground
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Text {
                    text: "Permissões do site:"
                    color: Theme.dimForeground
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6
                    Glyph { name: "check"; size: 11; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Cookies e armazenamento: Permitido"; color: Theme.foreground; font.pixelSize: 11 }
                }

                Row {
                    spacing: 6
                    Glyph { name: "check"; size: 11; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "JavaScript & Hardware Canvas: Ativo"; color: Theme.foreground; font.pixelSize: 11 }
                }

                Rectangle {
                    width: parent.width
                    height: 26
                    radius: root.itemRadius
                    color: clearSiteDataMouse.containsMouse ? Theme.selection : Qt.rgba(1, 1, 1, 0.05)
                    border.color: clearSiteDataMouse.containsMouse ? Theme.accent : Theme.border
                    border.width: 1

                    Text {
                        text: "Recarregar limpando cache"
                        color: Theme.foreground
                        font.pixelSize: 11
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: clearSiteDataMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            siteInfoPopup.visible = false;
                            root.webViewAction("reload");
                        }
                    }
                }
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // 1. TOP TYPING INPUT BAR (Clean, Omarchy style)
            Rectangle {
                id: topInputBar
                width: parent.width
                height: 50
                color: "transparent"

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (root.tabsModel && root.tabsModel.count > 1) {
                            var count = root.tabsModel.count;
                            var currentIdx = root.activeTabIndex;
                            var newIdx = currentIdx;
                            if (event.angleDelta.y > 0) {
                                newIdx = (currentIdx - 1 + count) % count;
                            } else if (event.angleDelta.y < 0) {
                                newIdx = (currentIdx + 1) % count;
                            }
                            if (newIdx !== currentIdx) {
                                root.switchTab(newIdx);
                                var tab = root.tabsModel.get(newIdx);
                                if (tab && tab.url && tab.url !== "about:blank") {
                                    inputQuery.text = tab.url;
                                } else {
                                    inputQuery.text = "";
                                }
                                inputQuery.selectAll();
                            }
                        }
                    }
                }

                // Left: Botão de Configuração da Página (Site Settings / SSL Padlock)
                Rectangle {
                    id: siteConfigBtn
                    width: 28
                    height: 28
                    radius: root.itemRadius
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: siteConfigMouse.containsMouse || siteInfoPopup.visible ? Theme.selection : "transparent"
                    border.color: siteConfigMouse.containsMouse || siteInfoPopup.visible ? Theme.accent : "transparent"
                    border.width: 1

                    Glyph {
                        name: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? "lock" :
                              ((bridge.currentUrl && bridge.currentUrl.indexOf("http://") === 0) ? "alert" : "sliders")
                        size: 13
                        color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Theme.green :
                               ((bridge.currentUrl && bridge.currentUrl.indexOf("http://") === 0) ? Theme.red : Theme.dimForeground)
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: siteConfigMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            siteInfoPopup.visible = !siteInfoPopup.visible;
                        }
                    }
                }

                // Right: Ações de Navegação, Tradução e Expandir/Contrair
                Row {
                    id: rightActionsRow
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Botão de Tradução (se habilitado em configurações)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        visible: root.cardConfig.enable_translation !== false && bridge.currentUrl.length > 0 && bridge.currentUrl !== "about:blank"
                        color: translateMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: translateMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "type"
                            size: 13
                            color: translateMouse.containsMouse ? Theme.accent : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: translateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.translateCurrentPage()
                        }
                    }

                    // Botão Voltar
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: backBtnMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: backBtnMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "arrow-left"
                            size: 13
                            color: Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: backBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.webViewAction("back")
                        }
                    }

                    // Botão Avançar
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: fwdBtnMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: fwdBtnMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "arrow-right"
                            size: 13
                            color: Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: fwdBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.webViewAction("forward")
                        }
                    }

                    // Botão Recarregar / Parar
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: reloadBtnMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: reloadBtnMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: bridge.isLoading ? "x" : "refresh"
                            size: 13
                            color: Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: reloadBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.webViewAction(bridge.isLoading ? "stop" : "reload")
                        }
                    }

                    // Botão Flip / Tela Dividida (Split Screen)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: (window && window.splitViewActive) ? Theme.selection : (splitBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: (window && window.splitViewActive) ? Theme.accent : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "dual"
                            size: 13
                            color: (window && window.splitViewActive) ? Theme.accent : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: splitBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.flipSplitRequested()
                        }
                    }

                    // Botão Expandir / Contrair (Seta para baixo contraído, Seta para cima expandido)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: root.isExpanded ? Theme.selection : (expandMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: root.isExpanded ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: root.isExpanded ? "chevron-up" : "chevron-down"
                            size: 13
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

                // Center: Main Text Input (Address Bar & Search)
                TextInput {
                    id: inputQuery
                    anchors.left: siteConfigBtn.right
                    anchors.right: rightActionsRow.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    focus: true
                    selectByMouse: true
                    clip: true

                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            if (root.tabsModel && root.tabsModel.count > 1) {
                                var count = root.tabsModel.count;
                                var currentIdx = root.activeTabIndex;
                                var newIdx = currentIdx;
                                if (event.angleDelta.y > 0) {
                                    newIdx = (currentIdx - 1 + count) % count;
                                } else if (event.angleDelta.y < 0) {
                                    newIdx = (currentIdx + 1) % count;
                                }
                                if (newIdx !== currentIdx) {
                                    root.switchTab(newIdx);
                                    var tab = root.tabsModel.get(newIdx);
                                    if (tab && tab.url && tab.url !== "about:blank") {
                                        inputQuery.text = tab.url;
                                    } else {
                                        inputQuery.text = "";
                                    }
                                    inputQuery.selectAll();
                                }
                            }
                        }
                    }

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
                        if (siteInfoPopup.visible) {
                            siteInfoPopup.visible = false;
                        } else {
                            root.isExpanded = false;
                            bridge.launcherVisible = false;
                        }
                    }

                    Component.onCompleted: {
                        if (root.visible) {
                            forceActiveFocus();
                            selectAll();
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
                visible: root.isExpanded
                clip: true

                DropArea {
                    id: pinnedDropArea
                    anchors.fill: parent
                    keys: ["tab-item"]
                    onDropped: function(drop) {
                        if (drop.source && drop.source.tabUrl) {
                            root.pinTab(drop.source.tabTitle, drop.source.tabUrl);
                            drop.accept();
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: root.itemRadius
                    color: pinnedDropArea.containsDrag ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.color: pinnedDropArea.containsDrag ? Theme.accent : "transparent"
                    border.width: 1
                    visible: pinnedDropArea.containsDrag
                }

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

                                    Item {
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: pin1Favicon
                                            anchors.fill: parent
                                            source: root.getFavicon(modelData.url, "")
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Glyph {
                                            anchors.centerIn: parent
                                            name: modelData.glyph || "globe"
                                            size: 13
                                            color: pin1Mouse.containsMouse ? Theme.accent : Theme.dimForeground
                                            visible: pin1Favicon.status !== Image.Ready
                                        }
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

                                    Item {
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: pin2Favicon
                                            anchors.fill: parent
                                            source: root.getFavicon(modelData.url, "")
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Glyph {
                                            anchors.centerIn: parent
                                            name: modelData.glyph || "globe"
                                            size: 13
                                            color: pin2Mouse.containsMouse ? Theme.accent : Theme.dimForeground
                                            visible: pin2Favicon.status !== Image.Ready
                                        }
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
            }

            // 3. SEARCH SUGGESTIONS (Aparece SOMENTE ao digitar quando não estiver expandido)
            ListView {
                id: resultsList
                width: parent.width
                height: (!root.isExpanded && inputQuery.text.trim().length > 0) ? (launcherCard.height - 50) : 0
                clip: true
                visible: !root.isExpanded && inputQuery.text.trim().length > 0
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

                        Item {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: resFavicon
                                anchors.fill: parent
                                source: root.getFavicon(model.url, "")
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready && model.isUrl
                            }

                            Glyph {
                                anchors.centerIn: parent
                                name: model.isUrl ? "globe" : "search"
                                size: 14
                                color: Theme.accent
                                visible: !model.isUrl || resFavicon.status !== Image.Ready
                            }
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
                visible: root.isExpanded
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

                        delegate: Item {
                            id: tabDelegate
                            width: tabsList.width
                            height: 30
                            visible: model.workspace === root.activeWorkspace

                            property string tabTitle: model.title || model.url || "Nova Aba"
                            property string tabUrl: model.url || ""

                            Rectangle {
                                id: tabRowRect
                                width: parent.width
                                height: parent.height
                                radius: root.itemRadius
                                color: root.activeTabIndex === index ? Theme.selection : (tabRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                                border.color: root.activeTabIndex === index ? Theme.accent : "transparent"
                                border.width: 1

                                Drag.active: tabRowMouse.drag.active
                                Drag.source: tabDelegate
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2
                                Drag.keys: ["tab-item"]

                                states: State {
                                    when: tabRowMouse.drag.active
                                    ParentChange { target: tabRowRect; parent: launcherCard }
                                    AnchorChanges {
                                        target: tabRowRect
                                        anchors.horizontalCenter: undefined
                                        anchors.verticalCenter: undefined
                                    }
                                    PropertyChanges {
                                        target: tabRowRect
                                        opacity: 0.9
                                        z: 9999
                                        border.color: Theme.accent
                                        border.width: 2
                                        color: Theme.surface
                                    }
                                }

                                MouseArea {
                                    id: tabRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    drag.target: tabRowRect
                                    drag.axis: Drag.XAndYAxis
                                    onClicked: {
                                        root.switchTab(index);
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    // Botão de Pinar na frente da aba
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: root.itemRadius
                                        color: pinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Glyph {
                                            name: "tag"
                                            size: 11
                                            color: root.isTabPinned(model.url) ? Theme.accent : (pinMouse.containsMouse ? Theme.foreground : Theme.dimForeground)
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: pinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.togglePinTab(model.title, model.url);
                                            }
                                        }
                                    }

                                    // Favicon do site na frente do endereço / título da aba aberta
                                    Item {
                                        width: 14
                                        height: 14
                                        anchors.verticalCenter: parent.verticalCenter

                                        Image {
                                            id: tabFavicon
                                            anchors.fill: parent
                                            source: root.getFavicon(model.url, model.favicon || "")
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }

                                        Glyph {
                                            anchors.centerIn: parent
                                            name: "globe"
                                            size: 12
                                            color: Theme.dimForeground
                                            visible: tabFavicon.status !== Image.Ready
                                        }
                                    }

                                    Text {
                                        text: model.title ? model.title : (model.url ? model.url : "Nova Aba Vazia")
                                        color: Theme.foreground
                                        font.pixelSize: 12
                                        font.bold: root.activeTabIndex === index
                                        elide: Text.ElideRight
                                        width: parent.width - 92
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
            }

            // 5. LINHA INFERIOR COM CONFIGURAÇÕES E BOTÃO DE LOGIN GOOGLE
            // Só aparece quando a caixa está expandida!
            Rectangle {
                id: bottomQuickBar
                width: parent.width
                height: 42
                color: "transparent"
                visible: root.isExpanded

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
    signal flipSplitRequested()

    function extractDomain(url) {
        if (!url) return "";
        try {
            var match = url.match(/^(?:https?:\/\/)?(?:www\.)?([^\/\?#:]+)/i);
            if (match && match[1]) {
                return match[1];
            }
        } catch(e) {}
        return url;
    }

    function getFavicon(url, localFavicon) {
        if (localFavicon && localFavicon.length > 0 && (localFavicon.indexOf("://") !== -1 || localFavicon.startsWith("data:") || localFavicon.startsWith("image:"))) {
            return localFavicon;
        }
        if (!url || url.length === 0 || url === "about:blank") return "";
        var domain = extractDomain(url);
        if (!domain || domain.indexOf(".") === -1) return "";
        return "https://www.google.com/s2/favicons?domain=" + domain + "&sz=32";
    }

    function formatUrl(query) {
        var text = (query || "").trim();
        if (!text) return "";

        // Se já possui protocolo
        if (text.match(/^(https?:\/\/|file:\/\/|ftp:\/\/|about:|chrome:\/\/)/i)) {
            return text;
        }

        // Se começa com www.
        if (text.match(/^www\./i)) {
            return "https://" + text;
        }

        // Localhost com porta opcional
        if (text.match(/^localhost(:[0-9]+)?(\/.*)?$/i)) {
            return "http://" + text;
        }

        // Endereço IP numérico
        if (text.match(/^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]+)?(\/.*)?$/)) {
            return "http://" + text;
        }

        // Qualquer domínio sem www (ex: google.com, youtube.com, globo.com, uol.com.br, reddit.com/r/archlinux)
        if (text.indexOf(" ") === -1 && text.indexOf(".") !== -1) {
            var host = text.split("/")[0].split("?")[0].split("#")[0];
            var hostParts = host.split(".");
            var tld = hostParts[hostParts.length - 1].split(":")[0];
            if (tld && tld.length >= 2 && !tld.match(/[^a-zA-Z]/)) {
                return "https://" + text;
            }
        }

        // Fallback para pesquisa no Google
        return "https://www.google.com/search?q=" + encodeURIComponent(text);
    }

    function translateCurrentPage() {
        if (!bridge.currentUrl || bridge.currentUrl.length === 0 || bridge.currentUrl === "about:blank") return;
        var translateUrl = "https://translate.google.com/translate?sl=auto&tl=pt&u=" + encodeURIComponent(bridge.currentUrl);
        root.openUrlInTab(translateUrl);
    }

    function executeAction(text) {
        var query = text.trim();
        if (!query) return;

        var targetUrl = root.formatUrl(query);
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
        bridge.launcherVisible = true;
        inputQuery.text = "";
        inputQuery.forceActiveFocus();
    }

    function switchTab(index) {
        switchTabRequested(index);
    }

    function closeTab(index) {
        closeTabRequested(index);
    }

    function isTabPinned(url) {
        if (!url || url.length === 0) return false;
        for (var i = 0; i < root.pinnedRow1.length; i++) {
            if (root.pinnedRow1[i].url === url) return true;
        }
        for (var j = 0; j < root.pinnedRow2.length; j++) {
            if (root.pinnedRow2[j].url === url) return true;
        }
        return false;
    }

    function pinTab(title, url) {
        if (!url || url === "" || url === "about:blank") return;
        var r1 = root.pinnedRow1.slice();
        var r2 = root.pinnedRow2.slice();

        // Check if already pinned
        for (var i = 0; i < r1.length; i++) {
            if (r1[i].url === url) return;
        }
        for (var j = 0; j < r2.length; j++) {
            if (r2[j].url === url) return;
        }

        var label = title || extractDomain(url);
        if (label.length > 10) label = label.substring(0, 9) + "…";
        var item = { name: label, url: url, glyph: "globe" };

        if (r1.length < 6) {
            r1.push(item);
            root.pinnedRow1 = r1;
        } else {
            r2.unshift(item);
            if (r2.length > 6) r2.pop();
            root.pinnedRow2 = r2;
        }
    }

    function unpinTab(url) {
        var r1 = root.pinnedRow1.filter(function(it) { return it.url !== url; });
        var r2 = root.pinnedRow2.filter(function(it) { return it.url !== url; });
        root.pinnedRow1 = r1;
        root.pinnedRow2 = r2;
    }

    function togglePinTab(title, url) {
        if (isTabPinned(url)) {
            unpinTab(url);
        } else {
            pinTab(title, url);
        }
    }

    function filterResults(query) {
        resultsModel.clear();
        var q = query.trim();
        if (!q) return;

        var targetUrl = root.formatUrl(q);
        var isUrl = !targetUrl.startsWith("https://www.google.com/search?q=");

        // 1. Direct search or URL suggestion
        resultsModel.append({
            isUrl: isUrl,
            title: isUrl ? ("Ir para: " + q) : ("Pesquisar: \"" + query + "\""),
            url: targetUrl
        });

        // 2. Bookmarks from Chrome
        try {
            var bookmarks = JSON.parse(bridge.bookmarksJson || "[]");
            var bCount = 0;
            var qLower = q.toLowerCase();
            for (var i = 0; i < bookmarks.length && bCount < 5; i++) {
                var b = bookmarks[i];
                if ((b.title && b.title.toLowerCase().indexOf(qLower) !== -1) || (b.url && b.url.toLowerCase().indexOf(qLower) !== -1)) {
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
            var qLowerH = q.toLowerCase();
            for (var j = 0; j < history.length && hCount < 6; j++) {
                var h = history[j];
                if ((h.title && h.title.toLowerCase().indexOf(qLowerH) !== -1) || (h.url && h.url.toLowerCase().indexOf(qLowerH) !== -1)) {
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

    onActiveTabIndexChanged: {
        if (bridge.launcherVisible && tabsModel && activeTabIndex >= 0 && activeTabIndex < tabsModel.count) {
            var tab = tabsModel.get(activeTabIndex);
            if (tab && tab.url && tab.url !== "about:blank") {
                inputQuery.text = tab.url;
            } else {
                inputQuery.text = "";
            }
            inputQuery.selectAll();
        }
    }

    onVisibleChanged: {
        if (visible) {
            inputQuery.text = (bridge.currentUrl && bridge.currentUrl !== "about:blank") ? bridge.currentUrl : "";
            inputQuery.forceActiveFocus();
            inputQuery.selectAll();
        } else {
            siteInfoPopup.visible = false;
        }
    }

    Connections {
        target: bridge
        function onCurrentUrlChanged() {
            if (!inputQuery.activeFocus) {
                inputQuery.text = (bridge.currentUrl && bridge.currentUrl !== "about:blank") ? bridge.currentUrl : "";
            }
        }

        function onLauncherVisibleChanged() {
            if (bridge.launcherVisible) {
                inputQuery.text = (bridge.currentUrl && bridge.currentUrl !== "about:blank") ? bridge.currentUrl : "";
                inputQuery.forceActiveFocus();
                inputQuery.selectAll();
            } else {
                root.isExpanded = false;
                siteInfoPopup.visible = false;
            }
        }
    }
}
