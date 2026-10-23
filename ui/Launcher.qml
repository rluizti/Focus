import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: root
    visible: bridge.launcherVisible
    anchors.fill: parent
    z: 500
    focus: visible
    Keys.onEscapePressed: function(event) {
        if (root.isSiteConfigExpanded) {
            root.isSiteConfigExpanded = false;
        } else {
            root.isExpanded = false;
            bridge.launcherVisible = false;
        }
        event.accepted = true;
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.isSiteConfigExpanded) {
                root.isSiteConfigExpanded = false;
            } else {
                root.isExpanded = false;
                bridge.launcherVisible = false;
            }
            event.accepted = true;
        }
    }

    signal requestBitwardenUnlock()
    signal requestHistoryModal()
    signal translatePageRequested(string targetLang)

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
                root.isSiteConfigExpanded = false;
            }
        }
    }

    // Workspaces and Tab Groups State
    property var workspaces: ["Principal", "Trabalho", "Pessoal"]
    property string activeWorkspace: "Principal"
    property var workspaceGroups: ({ "Principal": ["Geral"], "Trabalho": ["Geral"], "Pessoal": ["Geral"] })
    property var collapsedGroups: ({})
    property int groupsVersion: 0
    property string activeGroupName: "Agora"
    property var sessionRecentTabIds: []
    property string dragOverGroupName: ""
    property string dragReorderTargetGroup: ""
    property int dragReorderTargetTabIndex: -1
    // Pinned rows only appear when user clicks to expand the box
    property bool isExpanded: false
    property bool isSiteConfigExpanded: false
    property bool bookmarksBarExpanded: false
    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    property string hoverTooltipText: ""
    function showTooltip(item, txt) {
        if (!item || !txt || txt.length === 0) return;
        var pt = item.mapToItem(root, item.width / 2, item.height);
        globalHoverTooltip.x = Math.max(10, Math.min(root.width - globalHoverTooltip.width - 10, pt.x - globalHoverTooltip.width / 2));
        if (pt.y + 36 > root.height) {
            globalHoverTooltip.y = pt.y - item.height - 30;
        } else {
            globalHoverTooltip.y = pt.y + 6;
        }
        root.hoverTooltipText = txt;
    }
    function hideTooltip() {
        root.hoverTooltipText = "";
    }

    property var cardConfig: {
        try {
            return JSON.parse(bridge.configJson)
        } catch(e) {
            return { enable_translation: true }
        }
    }

    property var googleAccount: {
        try {
            return JSON.parse(bridge.googleAccountJson);
        } catch(e) {
            return { isLoggedIn: false, name: "", givenName: "", email: "", avatar: "" };
        }
    }

    Connections {
        target: bridge
        function onGoogleAccountChanged() {
            try {
                root.googleAccount = JSON.parse(bridge.googleAccountJson);
            } catch(e) {}
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
        // 3. Site config expanded: adds 140px full width, pushing content down!
        // 4. Resting: ONLY typing input box (50px)!
        height: {
            var total = root.isExpanded ? 52 : 50;
            if (root.isSiteConfigExpanded) {
                total += 205;
            }
            if (root.isExpanded) {
                var tabsH = (typeof tabsSection !== "undefined" && tabsSection) ? tabsSection.computedTabsSectionHeight : 140;
                total += 94 + tabsH + 42;
                if (root.bookmarksBarExpanded) {
                    total += 42;
                }
            } else if (inputQuery.text.trim().length > 0) {
                total = Math.min(460, total + resultsModel.count * 42);
            }
            return Math.min(Math.max(200, root.height - 60), total);
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
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: function(mouse) { mouse.accepted = true; }
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // 1. TOP TYPING INPUT BAR (Clean, Omarchy style)
            Rectangle {
                id: topInputBar
                width: parent.width
                height: root.isExpanded ? 52 : 50
                color: "transparent"

                DragHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    xAxis.enabled: false
                    yAxis.enabled: true
                    onTranslationChanged: {
                        if (translation.y > 18 && !root.isExpanded) {
                            root.isExpanded = true;
                        } else if (translation.y < -18 && root.isExpanded) {
                            root.isExpanded = false;
                        }
                    }
                }

                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (root.activeGroupTabs && root.activeGroupTabs.length > 1) {
                            var count = root.activeGroupTabs.length;
                            var curGroupTabIdx = -1;
                            for (var k = 0; k < count; k++) {
                                if (root.activeGroupTabs[k].globalIndex === root.activeTabIndex) {
                                    curGroupTabIdx = k;
                                    break;
                                }
                            }
                            if (curGroupTabIdx === -1) curGroupTabIdx = 0;
                            var newGroupTabIdx = curGroupTabIdx;
                            if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                                newGroupTabIdx = (curGroupTabIdx - 1 + count) % count;
                            } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                                newGroupTabIdx = (curGroupTabIdx + 1) % count;
                            }
                            if (newGroupTabIdx !== curGroupTabIdx) {
                                var targetGlobal = root.activeGroupTabs[newGroupTabIdx].globalIndex;
                                root.switchTab(targetGlobal);
                                var tab = root.tabsModel.get(targetGlobal);
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

                // Left: Botão de Configuração do Site + Plugins Pinados + Seletor de Grupos
                Row {
                    id: leftSiteBar
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Botão de Configuração da Página (Site Settings / SSL Padlock)
                    Rectangle {
                        id: siteConfigBtn
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: siteConfigMouse.containsMouse || root.isSiteConfigExpanded ? Theme.selection : "transparent"
                        border.color: siteConfigMouse.containsMouse || root.isSiteConfigExpanded ? Theme.accent : "transparent"
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
                            onEntered: root.showTooltip(siteConfigBtn, (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? "Conexão Segura (HTTPS)" : "Configurações do Site")
                            onExited: root.hideTooltip()
                            onClicked: {
                                root.isSiteConfigExpanded = !root.isSiteConfigExpanded;
                            }
                        }
                    }


                    // Plugin Pinado 2: Bitwarden
                    Rectangle {
                        id: pinBitwardenBtn
                        width: 28
                        height: 28
                        radius: root.itemRadius
                        color: pinBwMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: pinBwMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1
                        visible: {
                            try {
                                var cfg = JSON.parse(bridge.configJson);
                                return cfg.bitwarden_enabled === true;
                            } catch(e) { return false; }
                        }

                        Glyph {
                            name: "shield"
                            size: 13
                            color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: pinBwMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(pinBitwardenBtn, bridge.bitwardenUnlocked ? "Bitwarden (Cofre Desbloqueado)" : "Bitwarden (Cofre Bloqueado)")
                            onExited: root.hideTooltip()
                            onClicked: {
                                if (!bridge.bitwardenUnlocked) {
                                    root.requestBitwardenUnlock();
                                } else {
                                    bridge.openBitwarden();
                                }
                            }
                        }
                    }

                    // Seletor de Grupos do Espaço Ativo (À direita do Bitwarden, sem círculo, com silhueta Omarchy e expansão do nome no hover)
                    Rectangle {
                        id: groupSelectorBtn
                        height: 28
                        radius: root.itemRadius
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: groupHover.containsMouse ? Theme.selection : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        border.color: groupHover.containsMouse ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                        border.width: 1

                        // Largura se expande suavemente no hover para mostrar o nome completo à direita do ícone
                        width: groupHover.containsMouse ? Math.max(28, 28 + groupFullNameTxt.implicitWidth + 14) : 28

                        Behavior on width {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 140 }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            // Caixa do Ícone (28x28 com a silhueta da logo do sistema e a primeira letra do grupo)
                            Item {
                                width: 28
                                height: 28

                                // Silhueta da logo do sistema (Omarchy)
                                Image {
                                    id: omarchySilhouette
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: "file:///usr/share/omarchy/icon.png"
                                    fillMode: Image.PreserveAspectFit
                                    opacity: groupHover.containsMouse ? 0.45 : 0.25
                                    smooth: true
                                    Behavior on opacity {
                                        NumberAnimation { duration: 140 }
                                    }
                                }

                                // Primeira letra do grupo atual sobreposta à silhueta
                                Text {
                                    id: groupInitialTxt
                                    text: {
                                        var dummy = root.groupsVersion;
                                        var name = root.activeGroupName || "G";
                                        return name.charAt(0).toUpperCase();
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.accent
                                    anchors.centerIn: parent
                                }
                            }

                            // Nome completo do grupo (surge à direita da letra/ícone no hover)
                            Text {
                                id: groupFullNameTxt
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.activeGroupName || "Geral"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.foreground
                                opacity: groupHover.containsMouse ? 1.0 : 0.0
                                leftPadding: 4

                                Behavior on opacity {
                                    NumberAnimation { duration: 130 }
                                }
                            }
                        }

                        // Rolagem com o mouse em cima da letra do grupo alterna entre os grupos do espaço selecionado
                        WheelHandler {
                            target: groupSelectorBtn
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: function(event) {
                                var grps = root.getGroupSwitcherOptions(root.activeWorkspace);
                                if (grps.length > 1) {
                                    var curIdx = grps.indexOf(root.activeGroupName);
                                    if (curIdx === -1) curIdx = 0;
                                    var newIdx = curIdx;
                                    if (event.angleDelta.y > 0) {
                                        newIdx = (curIdx - 1 + grps.length) % grps.length;
                                    } else if (event.angleDelta.y < 0) {
                                        newIdx = (curIdx + 1) % grps.length;
                                    }
                                    root.activeGroupName = grps[newIdx];
                                    root.groupsVersion++;
                                }
                            }
                        }

                        MouseArea {
                            id: groupHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: root.showTooltip(groupSelectorBtn, "Grupo: " + (root.activeGroupName || "Agora") + " • Clique para escolher")
                            onExited: root.hideTooltip()
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    if (root.activeGroupName !== "Agora") {
                                        var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                        grpContextMenu.openMenu(root.activeGroupName, pt.x, pt.y);
                                    }
                                } else {
                                    groupSwitcherMenu.openAtButton();
                                }
                            }
                        }

                        Popup {
                            id: groupSwitcherMenu
                            parent: root
                            width: 190
                            height: groupSwitcherColumn.childrenRect.height + 10
                            padding: 5
                            modal: false
                            focus: true
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                            z: 100000

                            function openAtButton() {
                                var point = groupSelectorBtn.mapToItem(root, 0, groupSelectorBtn.height + 4);
                                x = Math.max(8, Math.min(root.width - width - 8, point.x));
                                y = Math.max(8, Math.min(root.height - height - 8, point.y));
                                open();
                            }

                            background: Rectangle {
                                radius: root.itemRadius
                                color: Theme.surface
                                border.color: Theme.activeBorder
                                border.width: 1
                            }

                            contentItem: Column {
                                id: groupSwitcherColumn
                                width: groupSwitcherMenu.width - 10
                                spacing: 2

                                Repeater {
                                    model: root.getGroupSwitcherOptions(root.activeWorkspace)

                                    Rectangle {
                                        width: groupSwitcherMenu.width - 10
                                        height: 28
                                        radius: root.itemRadius
                                        color: groupOptionMouse.containsMouse || root.activeGroupName === modelData ? Theme.selection : "transparent"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 8

                                            Glyph {
                                                name: modelData === "Agora" ? "history" : "folder"
                                                size: 12
                                                color: root.activeGroupName === modelData ? Theme.accent : Theme.dimForeground
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.bold: root.activeGroupName === modelData
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: groupOptionMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.activeGroupName = modelData;
                                                root.groupsVersion++;
                                                groupSwitcherMenu.close();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divisor sutil
                    Rectangle {
                        width: 1
                        height: 16
                        color: Theme.border
                        anchors.verticalCenter: parent.verticalCenter
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
                            onEntered: root.showTooltip(parent, "Traduzir Página (Google Tradutor)")
                            onExited: root.hideTooltip()
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
                            onEntered: root.showTooltip(parent, "Voltar Página")
                            onExited: root.hideTooltip()
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
                            onEntered: root.showTooltip(parent, "Avançar Página")
                            onExited: root.hideTooltip()
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
                            onEntered: root.showTooltip(parent, bridge.isLoading ? "Parar Carregamento" : "Recarregar Página")
                            onExited: root.hideTooltip()
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
                            onEntered: root.showTooltip(parent, "Tela Dividida (Dual View)")
                            onExited: root.hideTooltip()
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
                            onEntered: root.showTooltip(parent, root.isExpanded ? "Contrair Painel" : "Espaços de Trabalho e Abas")
                            onExited: root.hideTooltip()
                            onClicked: {
                                root.isExpanded = !root.isExpanded;
                            }
                        }
                    }
                }

                // Center: Main Text Input (Address Bar & Search)
                TextInput {
                    id: inputQuery
                    anchors.left: leftSiteBar.right
                    anchors.right: rightActionsRow.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (root.isExpanded && root.activeGroupTabs && root.activeGroupTabs.length > 0) ? -6 : 0
                    color: Theme.foreground
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    focus: true
                    selectByMouse: true
                    clip: true

                    // Rolagem sobre o endereço alterna as páginas (abas) do grupo em questão
                    WheelHandler {
                        target: inputQuery
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            if (root.activeGroupTabs && root.activeGroupTabs.length > 1) {
                                var count = root.activeGroupTabs.length;
                                var curGroupTabIdx = -1;
                                for (var k = 0; k < count; k++) {
                                    if (root.activeGroupTabs[k].globalIndex === root.activeTabIndex) {
                                        curGroupTabIdx = k;
                                        break;
                                    }
                                }
                                if (curGroupTabIdx === -1) curGroupTabIdx = 0;
                                var newGroupTabIdx = curGroupTabIdx;
                                if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                                    newGroupTabIdx = (curGroupTabIdx - 1 + count) % count;
                                } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                                    newGroupTabIdx = (curGroupTabIdx + 1) % count;
                                }
                                if (newGroupTabIdx !== curGroupTabIdx) {
                                    var targetGlobal = root.activeGroupTabs[newGroupTabIdx].globalIndex;
                                    root.switchTab(targetGlobal);
                                    var tab = root.tabsModel.get(targetGlobal);
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
                        if (root.isSiteConfigExpanded) {
                            root.isSiteConfigExpanded = false;
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

                // Faixa deslizante de pontos com pequenos números (Fica DENTRO da caixa de endereço quando expande)
                Rectangle {
                    id: pageDotsStrip
                    height: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 200, Math.max(26, (root.activeGroupTabs ? root.activeGroupTabs.length : 0) * 32 + 10))
                    color: "transparent"
                    visible: root.isExpanded && root.activeGroupTabs && root.activeGroupTabs.length > 0
                    clip: true

                    ListView {
                        id: pageDotsList
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.activeGroupTabs

                        preferredHighlightBegin: parent.width / 2 - 14
                        preferredHighlightEnd: parent.width / 2 + 14
                        highlightRangeMode: ListView.StrictlyEnforceRange

                        Connections {
                            target: root
                            function onActiveTabIndexChanged() {
                                if (root.activeGroupTabs) {
                                    for (var i = 0; i < root.activeGroupTabs.length; i++) {
                                        if (root.activeGroupTabs[i].globalIndex === root.activeTabIndex) {
                                            pageDotsList.positionViewAtIndex(i, ListView.Center);
                                            break;
                                        }
                                    }
                                }
                            }
                        }

                        delegate: Rectangle {
                            id: dotItem
                            readonly property bool isActive: modelData && modelData.globalIndex === root.activeTabIndex
                            width: isActive ? 28 : 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: isActive ? Theme.accent : (dotMouse.containsMouse ? Theme.selection : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.90))
                            border.color: isActive ? Theme.accent : (dotMouse.containsMouse ? Theme.accent : Qt.rgba(255, 255, 255, 0.22))
                            border.width: 1

                            Behavior on width {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            Text {
                                text: (index + 1).toString()
                                anchors.centerIn: parent
                                font.pixelSize: 11
                                font.bold: true
                                font.family: Theme.fontFamily
                                color: dotItem.isActive ? Theme.background : Theme.foreground
                            }

                            MouseArea {
                                id: dotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.showTooltip(dotItem, "Aba " + (index + 1) + ": " + (modelData ? modelData.title : ""))
                                onExited: root.hideTooltip()
                                onClicked: {
                                    if (modelData) {
                                        root.switchTab(modelData.globalIndex);
                                        var tab = root.tabsModel.get(modelData.globalIndex);
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

                        Behavior on contentX {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }

                    // Rolagem sobre a faixa de números alterna as abas do grupo em questão
                    WheelHandler {
                        target: pageDotsStrip
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            if (root.activeGroupTabs && root.activeGroupTabs.length > 1) {
                                var count = root.activeGroupTabs.length;
                                var curGroupTabIdx = -1;
                                for (var k = 0; k < count; k++) {
                                    if (root.activeGroupTabs[k].globalIndex === root.activeTabIndex) {
                                        curGroupTabIdx = k;
                                        break;
                                    }
                                }
                                if (curGroupTabIdx === -1) curGroupTabIdx = 0;
                                var newGroupTabIdx = curGroupTabIdx;
                                if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                                    newGroupTabIdx = (curGroupTabIdx - 1 + count) % count;
                                } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                                    newGroupTabIdx = (curGroupTabIdx + 1) % count;
                                }
                                if (newGroupTabIdx !== curGroupTabIdx) {
                                    var targetGlobal = root.activeGroupTabs[newGroupTabIdx].globalIndex;
                                    root.switchTab(targetGlobal);
                                    var tab = root.tabsModel.get(targetGlobal);
                                    if (tab && tab.url && tab.url !== "about:blank") {
                                        inputQuery.text = tab.url;
                                    } else {
                                        inputQuery.text = "";
                                    }
                                    inputQuery.selectAll();
                                    pageDotsList.positionViewAtIndex(newGroupTabIdx, ListView.Center);
                                }
                            }
                        }
                    }
                }
            }

            // SITE CONFIGURATION INLINE PANEL (Expande na largura total, empurrando o conteúdo para baixo)
            Rectangle {
                id: siteConfigExpandedPanel
                width: parent.width
                height: root.isSiteConfigExpanded ? 205 : 0
                clip: true
                visible: height > 0
                color: Qt.rgba(0, 0, 0, 0.15)

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                    anchors.top: parent.top
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: root.itemRadius
                            color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(0.8, 0.2, 0.2, 0.15)
                            border.color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Theme.green : Theme.red
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Glyph {
                                name: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? "lock" : "alert"
                                size: 16
                                color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Theme.green : Theme.red
                                anchors.centerIn: parent
                            }
                        }

                        Column {
                            width: parent.width - 230
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: root.extractDomain(bridge.currentUrl) || "Configurações da Página"
                                color: Theme.foreground
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0)
                                    ? "Conexão segura (HTTPS) • Certificado Válido"
                                    : ((bridge.currentUrl && bridge.currentUrl.indexOf("http://") === 0)
                                        ? "Atenção: Conexão não criptografada (HTTP)"
                                        : "Página interna do navegador")
                                color: (bridge.currentUrl && bridge.currentUrl.indexOf("https://") === 0) ? Theme.green : Theme.dimForeground
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Botão Recarregar Limpando Cache
                        Rectangle {
                            height: 28
                            width: 170
                            radius: root.itemRadius
                            color: clearSiteDataMouse.containsMouse ? Theme.selection : Qt.rgba(1, 1, 1, 0.05)
                            border.color: clearSiteDataMouse.containsMouse ? Theme.accent : Theme.border
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Glyph { name: "refresh"; size: 11; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "Limpar Cache & Recarregar"
                                    color: Theme.foreground
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: clearSiteDataMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.webViewAction("reload");
                                    root.isSiteConfigExpanded = false;
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Permissões do Site
                    Row {
                        width: parent.width
                        spacing: 24

                        Row {
                            spacing: 6
                            Glyph { name: "check"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Armazenamento & Cookies: Permitido"; color: Theme.foreground; font.pixelSize: 11 }
                        }

                        Row {
                            spacing: 6
                            Glyph { name: "check"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "JavaScript & Canvas: Ativo"; color: Theme.foreground; font.pixelSize: 11 }
                        }

                        Row {
                            spacing: 6
                            Glyph { name: "shield"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Isolamento Seguro: Ativo"; color: Theme.foreground; font.pixelSize: 11 }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Plugins e Extensões Pinados no Site
                    Row {
                        width: parent.width
                        spacing: 12

                        // Plugin 1: Google Tradutor
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 44
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: translateSiteMouse.containsMouse ? Theme.accent : Theme.border
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: root.itemRadius
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Glyph { name: "type"; size: 13; color: Theme.accent; anchors.centerIn: parent }
                                }

                                Column {
                                    width: parent.width - 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "Google Tradutor"
                                        color: Theme.foreground
                                        font.bold: true
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                    }
                                    Text {
                                        text: "Traduzir página ao vivo"
                                        color: Theme.dimForeground
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Rectangle {
                                    width: 74
                                    height: 24
                                    radius: root.itemRadius
                                    color: translateSiteMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "Traduzir"
                                        color: translateSiteMouse.containsMouse ? Theme.background : Theme.foreground
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                    }
                                }
                            }

                            MouseArea {
                                id: translateSiteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.translateCurrentPage();
                                    root.isSiteConfigExpanded = false;
                                }
                            }
                        }

                        // Plugin 2: Bitwarden
                        Rectangle {
                            width: (parent.width - 12) / 2
                            height: 44
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: bwSiteMouse.containsMouse ? Theme.accent : Theme.border
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: root.itemRadius
                                    color: bridge.bitwardenUnlocked ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Glyph {
                                        name: "shield"
                                        size: 13
                                        color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                                        anchors.centerIn: parent
                                    }
                                }

                                Column {
                                    width: parent.width - 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: "Bitwarden"
                                        color: Theme.foreground
                                        font.bold: true
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                    }
                                    Text {
                                        text: bridge.bitwardenUnlocked ? "✓ Desbloqueado" : "🔒 Bloqueado"
                                        color: bridge.bitwardenUnlocked ? Theme.green : Theme.dimForeground
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Rectangle {
                                    width: 74
                                    height: 24
                                    radius: root.itemRadius
                                    color: bwSiteMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: bridge.bitwardenUnlocked ? "Abrir" : "Desbloquear"
                                        color: bwSiteMouse.containsMouse ? Theme.background : Theme.foreground
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                    }
                                }
                            }

                            MouseArea {
                                id: bwSiteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!bridge.bitwardenUnlocked) {
                                        root.requestBitwardenUnlock();
                                    } else {
                                        bridge.openBitwarden();
                                    }
                                    root.isSiteConfigExpanded = false;
                                }
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

            // 4. ABAS E ESPAÇOS DE TRABALHO COM GRUPOS EXPANSÍVEIS
            Item {
                id: tabsSection
                width: parent.width

                property int totalContentHeight: {
                    var dummy = root.groupsVersion;
                    var ws = root.activeWorkspace;
                    var grps = root.getVisibleGroupsForWorkspace(ws);
                    var h = 0;
                    for (var g = 0; g < grps.length; g++) {
                        h += 30; // cabeçalho do grupo
                        var grp = grps[g];
                        if (grp === "Agora" || !root.isGroupCollapsed(ws, grp)) {
                            var tCount = grp === "Agora" ? root.activeGroupTabs.length : root.countTabsInGroup(ws, grp);
                            if (tCount === 0) {
                                h += 26; // linha informativa
                            } else {
                                h += tCount * 33;
                            }
                        }
                    }
                    return h;
                }
                property int maxTabsListHeight: {
                    var otherH = 50 + (root.isSiteConfigExpanded ? 205 : 0) + 94 + 50 + 42 + (root.bookmarksBarExpanded ? 42 : 0);
                    return Math.max(90, root.height - 80 - otherH);
                }
                property int computedTabsListHeight: Math.min(maxTabsListHeight, Math.max(90, totalContentHeight))
                property int computedTabsSectionHeight: computedTabsListHeight + 46

                height: computedTabsSectionHeight
                visible: root.isExpanded
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Espaços de Trabalho Bar (Workspaces do Lançador)
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
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                            wsContextMenu.openMenu(modelData, pt.x, pt.y);
                                        } else {
                                            root.activeWorkspace = modelData;
                                            root.ensureActiveGroup();
                                        }
                                    }
                                }
                            }
                        }

                        // Novo Espaço de Trabalho
                        Rectangle {
                            height: 25
                            width: 75
                            radius: root.itemRadius
                            color: "transparent"
                            border.color: Theme.border
                            border.width: 1

                            Text {
                                text: "+ Espaço"
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
                                    list.push("Espaço " + nextId);
                                    root.workspaces = list;
                                    root.activeWorkspace = "Espaço " + nextId;
                                }
                            }
                        }
                    }

                    // Lista de Grupos de Abas com Expansão e Retração ao Clicar
                    Flickable {
                        id: tabsFlickable
                        width: parent.width
                        height: tabsSection.computedTabsListHeight
                        contentWidth: width
                        contentHeight: groupsColumn.implicitHeight
                        clip: true
                        interactive: !tabDragAvatar.isDragging && !groupDragAvatar.isDragging
                        boundsBehavior: Flickable.StopAtBounds

                        Behavior on contentY {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }

                        Timer {
                            id: scrollTabsToBottomTimer
                            interval: 80
                            repeat: false
                            onTriggered: {
                                var maxY = Math.max(0, tabsFlickable.contentHeight - tabsFlickable.height);
                                tabsFlickable.contentY = maxY;
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Column {
                            id: groupsColumn
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: {
                                    var dummy = root.groupsVersion;
                                    return root.getVisibleGroupsForWorkspace(root.activeWorkspace);
                                }

                                Item {
                                    id: groupWrapper
                                    width: groupsColumn.width
                                    height: groupCol.implicitHeight
                                    implicitHeight: groupCol.implicitHeight
                                    property string groupName: modelData

                                    DropArea {
                                        id: groupDropArea
                                        anchors.fill: parent
                                        keys: ["focus-tab"]

                                        onDropped: function(drop) {
                                            var tabIdx = tabDragAvatar.dragTabIndex;
                                            if (tabIdx >= 0) {
                                                root.moveTabToGroup(tabIdx, groupWrapper.groupName);
                                            }
                                            tabDragAvatar.isDragging = false;
                                            root.dragOverGroupName = "";
                                            drop.accept();
                                        }
                                    }

                                    Column {
                                        id: groupCol
                                        width: parent.width
                                        spacing: 3
                                        property string groupName: modelData
                                        property bool isCollapsed: groupName !== "Agora" && root.isGroupCollapsed(root.activeWorkspace, groupName)
                                        property int tabsCount: {
                                            var dummy = root.groupsVersion;
                                            return groupName === "Agora" ? root.activeGroupTabs.length : root.countTabsInGroup(root.activeWorkspace, groupName);
                                        }
                                        property bool isDragOver: groupName !== "Agora" && (groupDropArea.containsDrag || (tabDragAvatar.isDragging && root.dragOverGroupName === groupName)) && tabDragAvatar.dragSourceGroup !== groupName
                                        property bool isReorderTarget: groupName !== "Agora" && groupDragAvatar.isDragging && root.dragReorderTargetGroup === groupName && groupDragAvatar.sourceGroup !== groupName

                                        // Cabeçalho do Grupo de Abas (Clique para expandir/retrair ou arraste para reorganizar)
                                        Rectangle {
                                            width: parent.width
                                            height: 26
                                            radius: root.itemRadius
                                            color: (groupCol.isDragOver || groupCol.isReorderTarget) ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (groupHeaderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                                            border.color: (groupCol.isDragOver || groupCol.isReorderTarget) ? Theme.accent : (groupHeaderMouse.containsMouse ? Theme.accent : Theme.border)
                                            border.width: (groupCol.isDragOver || groupCol.isReorderTarget) ? 2 : 1

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                // Ícone de Seta (Expandido vs Retraído)
                                                Glyph {
                                                    name: groupCol.isCollapsed ? "chevron-right" : "chevron-down"
                                                    size: 11
                                                    color: groupHeaderMouse.containsMouse ? Theme.accent : Theme.dimForeground
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Ícone de Pasta do Grupo
                                                Glyph {
                                                    name: "folder"
                                                    size: 12
                                                    color: Theme.accent
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Nome do Grupo
                                                Text {
                                                    text: groupCol.groupName
                                                    color: Theme.foreground
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Badge com quantidade de abas ou indicação de mover/reorganizar
                                                Rectangle {
                                                    height: 16
                                                    width: tabCountTxt.implicitWidth + 10
                                                    radius: 8
                                                    color: (groupCol.isDragOver || groupCol.isReorderTarget) ? Theme.accent : Qt.rgba(1, 1, 1, 0.06)
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Text {
                                                        id: tabCountTxt
                                                        anchors.centerIn: parent
                                                        text: groupCol.isDragOver ? "Solte para mover aqui" : (groupCol.isReorderTarget ? "Mover grupo para aqui" : (groupCol.tabsCount + (groupCol.tabsCount === 1 ? " aba" : " abas")))
                                                        font.pixelSize: 9
                                                        font.bold: groupCol.isDragOver || groupCol.isReorderTarget
                                                        color: (groupCol.isDragOver || groupCol.isReorderTarget) ? Theme.background : Theme.dimForeground
                                                    }
                                                }
                                            }

                                        // Botão + para adicionar aba diretamente neste grupo
                                        Rectangle {
                                            id: addTabToGroupBtn
                                            width: 20
                                            height: 20
                                        visible: groupCol.groupName !== "Agora"
                                            radius: root.itemRadius
                                            color: addTabToGroupMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                            anchors.right: parent.right
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            z: 2

                                            Glyph {
                                                name: "plus"
                                                size: 10
                                                color: addTabToGroupMouse.containsMouse ? Theme.accent : Theme.dimForeground
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: addTabToGroupMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.newTabInGroupRequested("", root.activeWorkspace, groupCol.groupName);
                                                    if (groupCol.isCollapsed) {
                                                        root.toggleGroupCollapsed(root.activeWorkspace, groupCol.groupName);
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: groupHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: groupDragAvatar.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            preventStealing: true

                                            property real pressX: 0
                                            property real pressY: 0
                                            property bool isPressed: false

                                            onPressed: function(mouse) {
                                                if (mouse.button === Qt.LeftButton && groupCol.groupName !== "Agora") {
                                                    isPressed = true;
                                                    pressX = mouse.x;
                                                    pressY = mouse.y;
                                                    groupDragAvatar.sourceGroup = groupCol.groupName;
                                                    var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                    groupDragAvatar.x = pt.x - 20;
                                                    groupDragAvatar.y = pt.y - 14;
                                                }
                                            }

                                            onPositionChanged: function(mouse) {
                                                if (isPressed && !groupDragAvatar.isDragging) {
                                                    var dx = mouse.x - pressX;
                                                    var dy = mouse.y - pressY;
                                                    if (Math.abs(dx) > 6 || Math.abs(dy) > 6) {
                                                        groupDragAvatar.isDragging = true;
                                                    }
                                                }
                                                if (groupDragAvatar.isDragging && groupDragAvatar.sourceGroup === groupCol.groupName) {
                                                    var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                    groupDragAvatar.x = pt.x - 20;
                                                    groupDragAvatar.y = pt.y - 14;
                                                    root.updateGroupDragOver(pt.x, pt.y);
                                                }
                                            }

                                            onReleased: function(mouse) {
                                                if (groupDragAvatar.isDragging && groupDragAvatar.sourceGroup === groupCol.groupName) {
                                                    var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                    root.checkDropReorderGroup(pt.x, pt.y, groupCol.groupName);
                                                    groupDragAvatar.isDragging = false;
                                                    root.dragReorderTargetGroup = "";
                                                    resetGroupDragTimer.restart();
                                                }
                                                isPressed = false;
                                            }

                                            onCanceled: {
                                                if (groupDragAvatar.isDragging) {
                                                    groupDragAvatar.isDragging = false;
                                                    root.dragReorderTargetGroup = "";
                                                    resetGroupDragTimer.restart();
                                                }
                                                isPressed = false;
                                            }

                                            onClicked: function(mouse) {
                                                if (!groupDragAvatar.isDragging) {
                                                    if (mouse.button === Qt.RightButton) {
                                                        if (groupCol.groupName !== "Agora") {
                                                            var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                            grpContextMenu.openMenu(groupCol.groupName, pt.x, pt.y);
                                                        }
                                                    } else {
                                                        root.activeGroupName = groupCol.groupName;
                                                        if (groupCol.groupName !== "Agora") {
                                                            root.toggleGroupCollapsed(root.activeWorkspace, groupCol.groupName);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Abas do Grupo (Expandem e retraem com o cabeçalho)
                                    Column {
                                        id: tabsInGroupCol
                                        width: parent.width
                                        spacing: 3
                                        visible: !groupCol.isCollapsed

                                        Repeater {
                                            model: root.tabsModel

                                            Item {
                                                id: tabDelegate
                                                property bool belongsToThisGroup: {
                                                    if (groupCol.groupName === "Agora") return root.isSessionNowTab(model.tabId);
                                                    var ws = (model.workspace && model.workspace.length > 0) ? model.workspace : "Principal";
                                                    var grp = (model.tabGroup && model.tabGroup.length > 0) ? model.tabGroup : "Geral";
                                                    return ws === root.activeWorkspace && grp === groupCol.groupName;
                                                }
                                                property alias rowRect: tabRowRect

                                                width: groupCol.width
                                                height: belongsToThisGroup ? 30 : 0
                                                visible: belongsToThisGroup

                                                Rectangle {
                                                    id: tabRowRect
                                                    width: parent.width
                                                    height: parent.height
                                                    radius: root.itemRadius
                                                    color: root.activeTabIndex === index ? Theme.selection : (root.dragReorderTargetTabIndex === index ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (tabRowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"))
                                                    border.color: root.activeTabIndex === index || root.dragReorderTargetTabIndex === index ? Theme.accent : "transparent"
                                                    border.width: root.dragReorderTargetTabIndex === index ? 2 : 1

                                                    MouseArea {
                                                        id: tabRowMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: tabDragAvatar.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        preventStealing: true

                                                        property real pressX: 0
                                                        property real pressY: 0
                                                        property bool isPressed: false

                                                        onPressed: function(mouse) {
                                                            if (mouse.button === Qt.LeftButton) {
                                                                isPressed = true;
                                                                pressX = mouse.x;
                                                                pressY = mouse.y;
                                                                tabDragAvatar.dragTabIndex = index;
                                                                tabDragAvatar.dragTabTitle = (model.title && model.title.length > 0) ? model.title : (model.url || "Nova Aba");
                                                                tabDragAvatar.dragTabUrl = model.url || "";
                                                                tabDragAvatar.dragSourceGroup = groupCol.groupName;
                                                                var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                                tabDragAvatar.x = pt.x - 20;
                                                                tabDragAvatar.y = pt.y - 16;
                                                            }
                                                        }

                                                        onPositionChanged: function(mouse) {
                                                            if (isPressed && !tabDragAvatar.isDragging) {
                                                                var dx = mouse.x - pressX;
                                                                var dy = mouse.y - pressY;
                                                                if (Math.abs(dx) > 6 || Math.abs(dy) > 6) {
                                                                    tabDragAvatar.isDragging = true;
                                                                }
                                                            }
                                                            if (tabDragAvatar.isDragging && tabDragAvatar.dragTabIndex === index) {
                                                                var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                                tabDragAvatar.x = pt.x - 20;
                                                                tabDragAvatar.y = pt.y - 16;
                                                                root.updateDragOverGroup(pt.x, pt.y);
                                                                root.dragReorderTargetTabIndex = -1;
                                                                for (var targetPos = 0; targetPos < tabsInGroupCol.count; targetPos++) {
                                                                    var targetDelegate = tabsInGroupCol.itemAt(targetPos);
                                                                    if (!targetDelegate || !targetDelegate.belongsToThisGroup || targetPos === index) continue;
                                                                    var targetCenter = targetDelegate.mapToItem(launcherCard, targetDelegate.width / 2, targetDelegate.height / 2);
                                                                    if (Math.abs(pt.y - targetCenter.y) <= targetDelegate.height / 2 + 5) {
                                                                        root.dragReorderTargetTabIndex = targetPos;
                                                                        break;
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        onReleased: function(mouse) {
                                                            if (tabDragAvatar.isDragging && tabDragAvatar.dragTabIndex === index) {
                                                                var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                                if (root.dragReorderTargetTabIndex >= 0) {
                                                                    var targetDelegate = tabsInGroupCol.itemAt(root.dragReorderTargetTabIndex);
                                                                    var targetCenter = targetDelegate.mapToItem(launcherCard, targetDelegate.width / 2, targetDelegate.height / 2);
                                                                    if (groupCol.groupName === "Agora") {
                                                                        root.reorderSessionTab(index, root.dragReorderTargetTabIndex, pt.y >= targetCenter.y);
                                                                    } else {
                                                                        root.reorderTab(index, root.dragReorderTargetTabIndex, pt.y >= targetCenter.y);
                                                                    }
                                                                } else {
                                                                    root.checkDropOnGroup(pt.x, pt.y, index, groupCol.groupName);
                                                                }
                                                                tabDragAvatar.isDragging = false;
                                                                root.dragOverGroupName = "";
                                                                root.dragReorderTargetTabIndex = -1;
                                                                resetDragTimer.restart();
                                                            }
                                                            isPressed = false;
                                                        }

                                                        onCanceled: {
                                                            if (tabDragAvatar.isDragging) {
                                                                tabDragAvatar.isDragging = false;
                                                                root.dragOverGroupName = "";
                                                                root.dragReorderTargetTabIndex = -1;
                                                                resetDragTimer.restart();
                                                            }
                                                            isPressed = false;
                                                        }

                                                        onClicked: function(mouse) {
                                                            if (mouse.button === Qt.RightButton) {
                                                                var pt = mapToItem(launcherCard, mouse.x, mouse.y);
                                                                tabContextMenu.openMenu(index, model, pt.x, pt.y);
                                                            } else {
                                                                if (!tabDragAvatar.isDragging) {
                                                                    root.switchTab(index);
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Item {
                                                        anchors.fill: parent
                                                        clip: true

                                                        // Botão de Pinar na frente da aba
                                                        Rectangle {
                                                            id: pinTabBtn
                                                            width: 22
                                                            height: 22
                                                            radius: root.itemRadius
                                                            color: pinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: 16
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            z: 2

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

                                                        // Favicon do site
                                                        Item {
                                                            id: tabFaviconItem
                                                            width: 14
                                                            height: 14
                                                            anchors.left: pinTabBtn.right
                                                            anchors.leftMargin: 6
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            z: 2

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

                                                        // Fechar Aba
                                                        Rectangle {
                                                            id: closeTabBtn
                                                            width: 20
                                                            height: 20
                                                            radius: root.itemRadius
                                                            color: closeTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                                            anchors.right: parent.right
                                                            anchors.rightMargin: 6
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            z: 2

                                                            Text {
                                                                text: "✕"
                                                                color: closeTabMouse.containsMouse ? Theme.accent : Theme.dimForeground
                                                                font.pixelSize: 11
                                                                font.bold: true
                                                                anchors.centerIn: parent
                                                            }

                                                            MouseArea {
                                                                id: closeTabMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: root.closeTab(index)
                                                            }
                                                        }

                                                        // Título da Aba
                                                        Text {
                                                            id: tabTitleText
                                                            text: model.title ? model.title : (model.url ? model.url : "Nova Aba Vazia")
                                                            color: Theme.foreground
                                                            font.pixelSize: 12
                                                            font.bold: root.activeTabIndex === index
                                                            elide: Text.ElideRight
                                                            clip: true
                                                            maximumLineCount: 1
                                                            anchors.left: tabFaviconItem.right
                                                            anchors.leftMargin: 8
                                                            anchors.right: closeTabBtn.left
                                                            anchors.rightMargin: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Placeholder informativo se o grupo estiver sem abas
                                        Rectangle {
                                            width: parent.width
                                            height: 24
                                            color: "transparent"
                                            visible: groupCol.tabsCount === 0

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Nenhuma aba neste grupo — clique no + para abrir uma aba"
                                                font.pixelSize: 10
                                                color: Theme.dimForeground
                                            }
                                        }
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

                    // Botão Conta Google / Perfil com Foto Circular na Barra Inferior
                    Rectangle {
                        id: googleUserBottomBtn
                        height: 26
                        width: (root.googleAccount && root.googleAccount.isLoggedIn && (root.googleAccount.name || root.googleAccount.givenName))
                               ? Math.min(160, Math.max(76, googleBottomName.implicitWidth + 38))
                               : 105
                        radius: root.itemRadius
                        color: googleBottomMouse.containsMouse ? Theme.selection : ((root.googleAccount && root.googleAccount.isLoggedIn) ? Qt.rgba(1, 1, 1, 0.06) : Theme.accent)
                        border.color: (root.googleAccount && root.googleAccount.isLoggedIn) ? (googleBottomMouse.containsMouse ? Theme.accent : Theme.border) : "transparent"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            // Foto de Perfil com Máscara Circular Real
                            Item {
                                id: avatarContainer
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: googleAvatarImg
                                    anchors.fill: parent
                                    source: (root.googleAccount && root.googleAccount.isLoggedIn && root.googleAccount.avatar) ? root.googleAccount.avatar : ""
                                    visible: false
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                }

                                Rectangle {
                                    id: avatarCircleMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: googleAvatarImg
                                    maskSource: avatarCircleMask
                                    visible: (root.googleAccount && root.googleAccount.isLoggedIn && root.googleAccount.avatar && root.googleAccount.avatar.length > 0 && googleAvatarImg.status === Image.Ready)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Theme.accent
                                    border.width: 1
                                    visible: (root.googleAccount && root.googleAccount.isLoggedIn && root.googleAccount.avatar && root.googleAccount.avatar.length > 0)
                                }

                                Glyph {
                                    name: "user"
                                    size: 11
                                    color: (root.googleAccount && root.googleAccount.isLoggedIn) ? Theme.accent : Theme.background
                                    anchors.centerIn: parent
                                    visible: !root.googleAccount || !root.googleAccount.isLoggedIn || !root.googleAccount.avatar || root.googleAccount.avatar.length === 0 || googleAvatarImg.status !== Image.Ready
                                }
                            }

                            // Apenas o Primeiro Nome do Usuário
                            Text {
                                id: googleBottomName
                                text: {
                                    if (!root.googleAccount || !root.googleAccount.isLoggedIn) {
                                        return "Fazer Login";
                                    }
                                    var raw = root.googleAccount.givenName || root.googleAccount.name || "";
                                    raw = raw.trim();
                                    if (raw.length > 0) {
                                        return raw.split(" ")[0]; // Somente o primeiro nome!
                                    }
                                    return "Conta Google";
                                }
                                color: (root.googleAccount && root.googleAccount.isLoggedIn) ? Theme.foreground : Theme.background
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: googleBottomMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(googleUserBottomBtn, (root.googleAccount && root.googleAccount.isLoggedIn) ? ("Conta Google: " + (root.googleAccount.name || root.googleAccount.email || "Conectado")) : "Fazer Login na Conta Google")
                            onExited: root.hideTooltip()
                            onClicked: {
                                if (root.googleAccount && root.googleAccount.isLoggedIn) {
                                    bridge.launcherVisible = false;
                                    bridge.settingsVisible = true;
                                } else {
                                    bridge.launcherVisible = false;
                                    root.navigateTo("https://accounts.google.com");
                                }
                            }
                        }
                    }

                    // Botão Criar Novo Grupo no Espaço Atual (Somente um +)
                    Rectangle {
                        id: newGroupBottomBtn
                        height: 26
                        width: 26
                        radius: root.itemRadius
                        color: newGroupBottomMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: newGroupBottomMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "plus"
                            size: 13
                            color: newGroupBottomMouse.containsMouse ? Theme.accent : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: newGroupBottomMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(newGroupBottomBtn, "Criar Novo Grupo neste Espaço")
                            onExited: root.hideTooltip()
                            onClicked: root.createNewGroupInActiveWorkspace()
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    spacing: 8

                    // Botão Bitwarden (Somente Ícone)
                    Rectangle {
                        id: bitwardenBottomBtn
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: bitwardenMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        visible: {
                            try {
                                var cfg = JSON.parse(bridge.configJson);
                                return cfg.bitwarden_enabled === true;
                            } catch(e) { return false; }
                        }

                        Glyph {
                            name: "shield"
                            size: 13
                            color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: bitwardenMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(bitwardenBottomBtn, bridge.bitwardenUnlocked ? "Bitwarden: Cofre Desbloqueado" : "Bitwarden: Desbloquear Cofre")
                            onExited: root.hideTooltip()
                            onClicked: {
                                if (!bridge.bitwardenUnlocked) {
                                    root.requestBitwardenUnlock();
                                } else {
                                    bridge.openBitwarden();
                                }
                            }
                        }
                    }

                    // Sincronizar Chrome
                    Rectangle {
                        id: syncChromeBtn
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: syncChromeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: syncChromeMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "refresh"; size: 12; color: syncChromeMouse.containsMouse ? Theme.accent : Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            id: syncChromeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(syncChromeBtn, "Sincronizar com Chrome / Chromium (Favoritos, Histórico e Abas)")
                            onExited: root.hideTooltip()
                            onClicked: bridge.syncChrome()
                        }
                    }

                    // Botão de Favoritos (Somente Ícone)
                    Rectangle {
                        id: favBottomBtn
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: root.bookmarksBarExpanded ? Qt.rgba(1, 1, 1, 0.14) : (favMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.color: root.bookmarksBarExpanded ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "star"
                            size: 13
                            color: root.bookmarksBarExpanded ? Theme.accent : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: favMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(favBottomBtn, root.bookmarksBarExpanded ? "Ocultar Barra de Favoritos" : "Exibir Barra de Favoritos")
                            onExited: root.hideTooltip()
                            onClicked: {
                                root.bookmarksBarExpanded = !root.bookmarksBarExpanded;
                            }
                        }
                    }

                    // Botão de Histórico (Somente Ícone)
                    Rectangle {
                        id: histBottomBtn
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: histMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            name: "history"
                            size: 13
                            color: Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: histMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(histBottomBtn, "Histórico de Navegação")
                            onExited: root.hideTooltip()
                            onClicked: {
                                bridge.launcherVisible = false;
                                root.requestHistoryModal();
                            }
                        }
                    }

                    // Botão de Configurações
                    Rectangle {
                        id: settingsBottomBtn
                        height: 26
                        width: 28
                        radius: root.itemRadius
                        color: settingsBottomMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: settingsBottomMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph { name: "settings"; size: 13; color: settingsBottomMouse.containsMouse ? Theme.accent : Theme.foreground; anchors.centerIn: parent }

                        MouseArea {
                            id: settingsBottomMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.showTooltip(settingsBottomBtn, "Configurações do Navegador")
                            onExited: root.hideTooltip()
                            onClicked: {
                                bridge.launcherVisible = false;
                                bridge.settingsVisible = true;
                            }
                        }
                    }
                }
            }

            // 4. BARRA EXPANSÍVEL DE FAVORITOS (Com rolagem lateral com roda do mouse)
            Rectangle {
                id: bookmarksStrip
                width: parent.width
                height: (root.isExpanded && root.bookmarksBarExpanded) ? 42 : 0
                visible: height > 0
                clip: true
                color: Qt.rgba(0, 0, 0, 0.20)

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                    anchors.top: parent.top
                }

                property var bookmarksList: {
                    try {
                        return JSON.parse(bridge.bookmarksJson || "[]");
                    } catch(e) {
                        return [];
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: bookmarksStrip.bookmarksList.length === 0
                    text: "Nenhum favorito encontrado"
                    color: Theme.dimForeground
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                }

                ListView {
                    id: bookmarksListView
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    orientation: ListView.Horizontal
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: bookmarksStrip.bookmarksList
                    clip: true

                    delegate: Rectangle {
                        height: 28
                        width: Math.min(180, Math.max(70, bRow.width + 16))
                        radius: root.itemRadius
                        color: bMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: bMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: bRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            spacing: 6

                            Glyph {
                                name: "star"
                                size: 11
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.title || modelData.url || "Favorito"
                                color: Theme.foreground
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 17
                            }
                        }

                        MouseArea {
                            id: bMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    root.newTabRequested(modelData.url, "Favoritos");
                                } else {
                                    bridge.launcherVisible = false;
                                    root.navigateTo(modelData.url);
                                }
                            }
                        }
                    }

                    Behavior on contentX {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }

                // Rolar com o mouse passar lateralmente deslizando
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y !== 0) {
                            var step = wheel.angleDelta.y * 1.5;
                            var maxScroll = Math.max(0, bookmarksListView.contentWidth - bookmarksListView.width);
                            bookmarksListView.contentX = Math.max(0, Math.min(maxScroll, bookmarksListView.contentX - step));
                            wheel.accepted = true;
                        } else if (wheel.angleDelta.x !== 0) {
                            var stepX = wheel.angleDelta.x * 1.5;
                            var maxScrollX = Math.max(0, bookmarksListView.contentWidth - bookmarksListView.width);
                            bookmarksListView.contentX = Math.max(0, Math.min(maxScrollX, bookmarksListView.contentX - stepX));
                            wheel.accepted = true;
                        }
                    }
                }
            }
        }

        // 6. MENUS DE CONTEXTO E MODAL DE RENOMEAR DENTRO DO LAUNCHER CARD
        // Menu de Contexto para Espaços de Trabalho (Workspaces)
        Item {
            id: wsContextMenu
            anchors.fill: parent
            visible: false
            z: 99999

            property string targetWorkspace: ""
            property real menuX: 0
            property real menuY: 0

            function openMenu(ws, px, py) {
                targetWorkspace = ws;
                menuX = Math.min(launcherCard.width - menuBox.width - 10, Math.max(10, px));
                menuY = Math.min(launcherCard.height - menuBox.height - 10, Math.max(10, py));
                visible = true;
            }

            function closeMenu() {
                visible = false;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: wsContextMenu.closeMenu()
            }

            Rectangle {
                id: menuBox
                x: wsContextMenu.menuX
                y: wsContextMenu.menuY
                width: 190
                height: menuCol.implicitHeight + 12
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.activeBorder
                border.width: 1

                Column {
                    id: menuCol
                    width: parent.width - 12
                    anchors.centerIn: parent
                    spacing: 2

                    // Opção 1: Renomear Espaço
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: renWsMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "rename"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Renomear Espaço"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: renWsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ws = wsContextMenu.targetWorkspace;
                                wsContextMenu.closeMenu();
                                renameModal.open("workspace", ws, -1, ws);
                            }
                        }
                    }

                    // Opção 2: Novo Grupo neste Espaço
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: addGrpMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "folder-plus"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Novo Grupo"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: addGrpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ws = wsContextMenu.targetWorkspace;
                                wsContextMenu.closeMenu();
                                root.activeWorkspace = ws;
                                root.createNewGroupInActiveWorkspace();
                            }
                        }
                    }

                    // Opção 3: Nova Aba neste Espaço
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: addTabWsMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "plus"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Nova Aba"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: addTabWsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ws = wsContextMenu.targetWorkspace;
                                wsContextMenu.closeMenu();
                                root.activeWorkspace = ws;
                                root.createNewTab("");
                            }
                        }
                    }

                    // Divisor
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                        visible: root.workspaces.length > 1
                    }

                    // Opção 4: Excluir Espaço
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        visible: root.workspaces.length > 1
                        color: delWsMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "trash"; size: 12; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Excluir Espaço"; color: Theme.red; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: delWsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var ws = wsContextMenu.targetWorkspace;
                                wsContextMenu.closeMenu();
                                root.deleteWorkspace(ws);
                            }
                        }
                    }
                }
            }
        }

        // Menu de Contexto para Grupos de Abas
        Item {
            id: grpContextMenu
            anchors.fill: parent
            visible: false
            z: 99999

            property string targetGroup: ""
            property real menuX: 0
            property real menuY: 0

            function openMenu(grp, px, py) {
                targetGroup = grp;
                menuX = Math.min(launcherCard.width - grpMenuBox.width - 10, Math.max(10, px));
                menuY = Math.min(launcherCard.height - grpMenuBox.height - 10, Math.max(10, py));
                visible = true;
            }

            function closeMenu() {
                visible = false;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: grpContextMenu.closeMenu()
            }

            Rectangle {
                id: grpMenuBox
                x: grpContextMenu.menuX
                y: grpContextMenu.menuY
                width: 190
                height: grpMenuCol.implicitHeight + 12
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.activeBorder
                border.width: 1

                Column {
                    id: grpMenuCol
                    width: parent.width - 12
                    anchors.centerIn: parent
                    spacing: 2

                    // Opção 1: Renomear Grupo
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: renGrpMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "rename"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Renomear Grupo"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: renGrpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var g = grpContextMenu.targetGroup;
                                grpContextMenu.closeMenu();
                                renameModal.open("group", g, -1, g);
                            }
                        }
                    }

                    // Opção 2: Nova Aba neste Grupo
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: addTabGrpMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "plus"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Nova Aba neste Grupo"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: addTabGrpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var g = grpContextMenu.targetGroup;
                                grpContextMenu.closeMenu();
                                root.newTabInGroupRequested("", root.activeWorkspace, g);
                                root.activeGroupName = g;
                            }
                        }
                    }

                    // Divisor
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                        visible: root.getGroupsForWorkspace(root.activeWorkspace).length > 1
                    }

                    // Opção 3: Excluir Grupo
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        visible: root.getGroupsForWorkspace(root.activeWorkspace).length > 1
                        color: delGrpMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "trash"; size: 12; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Excluir Grupo"; color: Theme.red; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: delGrpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var g = grpContextMenu.targetGroup;
                                grpContextMenu.closeMenu();
                                root.deleteGroup(g);
                            }
                        }
                    }
                }
            }
        }

        // Tab Drag Avatar (proxy item durante arrastar e soltar abas)
        Item {
            id: tabDragAvatar
            width: 220
            height: 32
            visible: isDragging
            z: 99990
            opacity: 0.95

            property bool isDragging: false
            property int dragTabIndex: -1
            property string dragTabTitle: ""
            property string dragTabUrl: ""
            property string dragSourceGroup: ""

            Drag.active: isDragging
            Drag.source: tabDragAvatar
            Drag.hotSpot.x: 20
            Drag.hotSpot.y: 16
            Drag.keys: ["focus-tab"]

            Rectangle {
                anchors.fill: parent
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1.5

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    spacing: 8

                    Glyph {
                        name: "globe"
                        size: 13
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: tabDragAvatar.dragTabTitle
                        color: Theme.foreground
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Timer {
            id: resetDragTimer
            interval: 80
            repeat: false
            onTriggered: {
                tabDragAvatar.dragTabIndex = -1;
                tabDragAvatar.dragTabTitle = "";
                tabDragAvatar.dragSourceGroup = "";
            }
        }

        // Group Drag Avatar (proxy item durante reorganizar grupos)
        Item {
            id: groupDragAvatar
            width: 200
            height: 28
            visible: isDragging
            z: 99992
            opacity: 0.95

            property bool isDragging: false
            property string sourceGroup: ""

            Rectangle {
                anchors.fill: parent
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1.5

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    spacing: 8

                    Glyph {
                        name: "folder"
                        size: 13
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: groupDragAvatar.sourceGroup
                        color: Theme.foreground
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Timer {
            id: resetGroupDragTimer
            interval: 80
            repeat: false
            onTriggered: {
                groupDragAvatar.sourceGroup = "";
            }
        }

        // Menu de Contexto para Abas
        Item {
            id: tabContextMenu
            anchors.fill: parent
            visible: false
            z: 99999

            property int targetIndex: -1
            property var targetModel: null
            property real menuX: 0
            property real menuY: 0
            property bool showGroupsMenu: false

            function openMenu(idx, modelObj, px, py) {
                targetIndex = idx;
                targetModel = modelObj;
                showGroupsMenu = false;
                menuX = Math.min(launcherCard.width - tabMenuBox.width - 10, Math.max(10, px));
                menuY = Math.min(launcherCard.height - tabMenuBox.height - 10, Math.max(10, py));
                visible = true;
            }

            function closeMenu() {
                visible = false;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: tabContextMenu.closeMenu()
            }

            Rectangle {
                id: tabMenuBox
                x: tabContextMenu.menuX
                y: Math.min(launcherCard.height - height - 10, tabContextMenu.menuY)
                width: 210
                height: tabMenuCol.implicitHeight + 12
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.activeBorder
                border.width: 1

                Column {
                    id: tabMenuCol
                    width: parent.width - 12
                    anchors.centerIn: parent
                    spacing: 2

                    // Opção 1: Renomear Aba
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: renTabMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "rename"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Renomear Aba"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: renTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var idx = tabContextMenu.targetIndex;
                                var currentTitle = (tabContextMenu.targetModel && tabContextMenu.targetModel.title) ? tabContextMenu.targetModel.title : "";
                                tabContextMenu.closeMenu();
                                renameModal.open("tab", "", idx, currentTitle);
                            }
                        }
                    }

                    // Opção 2: Duplicar Aba
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: dupTabMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "plus"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Duplicar Aba"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: dupTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var idx = tabContextMenu.targetIndex;
                                tabContextMenu.closeMenu();
                                root.duplicateTab(idx);
                            }
                        }
                    }

                    // Opção: Adicionar ao Grupo / Mover para Grupo
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: moveToGroupMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "folder"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Adicionar ao Grupo"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            name: tabContextMenu.showGroupsMenu ? "chevron-down" : "chevron-right"
                            size: 10
                            color: Theme.dimForeground
                        }
                        MouseArea {
                            id: moveToGroupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                tabContextMenu.showGroupsMenu = !tabContextMenu.showGroupsMenu;
                            }
                        }
                    }

                    // Lista Expansível de Grupos do Espaço Ativo
                    Rectangle {
                        width: parent.width
                        height: groupsSubCol.implicitHeight + 8
                        radius: root.itemRadius
                        visible: tabContextMenu.showGroupsMenu
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: Theme.border
                        border.width: 1

                        Column {
                            id: groupsSubCol
                            width: parent.width - 8
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: {
                                    var dummy = root.groupsVersion;
                                    return root.getGroupsForWorkspace(root.activeWorkspace);
                                }

                                Rectangle {
                                    id: grpPickItem
                                    width: parent.width
                                    height: 24
                                    radius: 4
                                    property string gName: modelData
                                    property bool isCurrent: {
                                        if (!tabContextMenu.targetModel) return false;
                                        var curG = tabContextMenu.targetModel.tabGroup || "Geral";
                                        return curG === gName;
                                    }
                                    color: grpPickMouse.containsMouse ? Theme.selection : (isCurrent ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        spacing: 6

                                        Glyph {
                                            name: "folder"
                                            size: 10
                                            color: grpPickItem.isCurrent ? Theme.accent : Theme.dimForeground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: grpPickItem.gName
                                            color: grpPickItem.isCurrent ? Theme.accent : Theme.foreground
                                            font.pixelSize: 10
                                            font.bold: grpPickItem.isCurrent
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: grpPickItem.width - 36
                                        }
                                    }

                                    Glyph {
                                        visible: grpPickItem.isCurrent
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        name: "check"
                                        size: 9
                                        color: Theme.accent
                                    }

                                    MouseArea {
                                        id: grpPickMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var idx = tabContextMenu.targetIndex;
                                            root.moveTabToGroup(idx, grpPickItem.gName);
                                            tabContextMenu.closeMenu();
                                        }
                                    }
                                }
                            }

                            // Opção de criar novo grupo diretamente
                            Rectangle {
                                width: parent.width
                                height: 24
                                radius: 4
                                color: newGrpPickMouse.containsMouse ? Theme.selection : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6
                                    spacing: 6

                                    Glyph {
                                        name: "plus"
                                        size: 10
                                        color: Theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Novo Grupo..."
                                        color: Theme.dimForeground
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: newGrpPickMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var idx = tabContextMenu.targetIndex;
                                        tabContextMenu.closeMenu();
                                        root.createNewGroupInActiveWorkspace();
                                        root.moveTabToGroup(idx, root.activeGroupName);
                                    }
                                }
                            }
                        }
                    }

                    // Opção 3: Copiar Link
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        visible: tabContextMenu.targetModel && tabContextMenu.targetModel.url && tabContextMenu.targetModel.url.length > 0
                        color: copyLinkMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "globe"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Copiar Link"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: copyLinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tabContextMenu.targetModel && tabContextMenu.targetModel.url) {
                                    bridge.copyToClipboard(tabContextMenu.targetModel.url);
                                }
                                tabContextMenu.closeMenu();
                            }
                        }
                    }

                    // Opção 4: Pinar / Desafixar
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: pinTabMenuMouse.containsMouse ? Theme.selection : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "tag"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: (tabContextMenu.targetModel && root.isTabPinned(tabContextMenu.targetModel.url)) ? "Desafixar Aba" : "Fixar Aba"
                                color: Theme.foreground
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: pinTabMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tabContextMenu.targetModel) {
                                    root.togglePinTab(tabContextMenu.targetModel.title, tabContextMenu.targetModel.url);
                                }
                                tabContextMenu.closeMenu();
                            }
                        }
                    }

                    // Divisor
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    // Opção 5: Fechar / Excluir Aba
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: root.itemRadius
                        color: closeTabMenuMouse.containsMouse ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : "transparent"
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 8
                            Glyph { name: "trash"; size: 12; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Fechar Aba"; color: Theme.red; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            id: closeTabMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var idx = tabContextMenu.targetIndex;
                                tabContextMenu.closeMenu();
                                root.closeTab(idx);
                            }
                        }
                    }
                }
            }
        }

        // Modal de Renomear (Espaço, Grupo ou Aba)
        Item {
            id: renameModal
            anchors.fill: parent
            visible: false
            z: 100000

            property string mode: "" // "workspace", "group", "tab"
            property string targetIdentifier: ""
            property int targetTabIndex: -1

            function open(m, ident, tabIdx, initialText) {
                mode = m;
                targetIdentifier = ident;
                targetTabIndex = tabIdx;
                renameInput.text = initialText || "";
                visible = true;
                renameInput.forceActiveFocus();
                renameInput.selectAll();
            }

            function close() {
                visible = false;
            }

            function save() {
                var val = renameInput.text.trim();
                if (val.length > 0) {
                    if (mode === "workspace") {
                        root.renameWorkspace(targetIdentifier, val);
                    } else if (mode === "group") {
                        root.renameGroup(targetIdentifier, val);
                    } else if (mode === "tab") {
                        if (root.tabsModel && targetTabIndex >= 0 && targetTabIndex < root.tabsModel.count) {
                            root.tabsModel.setProperty(targetTabIndex, "title", val);
                            bridge.saveSession(root.serializeSession());
                        }
                    }
                }
                close();
            }

            Rectangle {
                anchors.fill: parent
                color: "#75000000"
                MouseArea {
                    anchors.fill: parent
                    onClicked: renameModal.close()
                }
            }

            Rectangle {
                width: 320
                height: 125
                radius: root.itemRadius
                color: Theme.surface
                border.color: Theme.accent
                border.width: 1
                anchors.centerIn: parent

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: renameModal.mode === "workspace" ? "Renomear Espaço de Trabalho" :
                              (renameModal.mode === "group" ? "Renomear Grupo de Abas" : "Renomear Aba")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: root.itemRadius
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: Theme.border
                        border.width: 1

                        TextInput {
                            id: renameInput
                            anchors.fill: parent
                            anchors.margins: 6
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            selectByMouse: true
                            Keys.onReturnPressed: renameModal.save()
                            Keys.onEscapePressed: renameModal.close()
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Rectangle {
                            width: 70
                            height: 24
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: "Cancelar"
                                color: Theme.dimForeground
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: renameModal.close()
                            }
                        }

                        Rectangle {
                            width: 70
                            height: 24
                            radius: root.itemRadius
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: "Salvar"
                                color: Theme.background
                                font.pixelSize: 11
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: renameModal.save()
                            }
                        }
                    }
                }
            }
        }
    }

    // Pontos/bolinhas flutuantes com números das abas FORA da caixa de endereço (sem barrinha de fundo)
    Item {
        id: externalPageDotsStrip
        height: 26
        anchors.top: launcherCard.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: launcherCard.horizontalCenter
        width: Math.min(launcherCard.width - 200, Math.max(26, (root.activeGroupTabs ? root.activeGroupTabs.length : 0) * 32 + 10))
        visible: !root.isExpanded && root.activeGroupTabs && root.activeGroupTabs.length > 0
        z: 9999

        Behavior on width {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        ListView {
            id: extPageDotsList
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.activeGroupTabs

            preferredHighlightBegin: parent.width / 2 - 14
            preferredHighlightEnd: parent.width / 2 + 14
            highlightRangeMode: ListView.StrictlyEnforceRange

            Connections {
                target: root
                function onActiveTabIndexChanged() {
                    if (root.activeGroupTabs) {
                        for (var i = 0; i < root.activeGroupTabs.length; i++) {
                            if (root.activeGroupTabs[i].globalIndex === root.activeTabIndex) {
                                extPageDotsList.positionViewAtIndex(i, ListView.Center);
                                break;
                            }
                        }
                    }
                }
            }

            delegate: Rectangle {
                id: extDotItem
                readonly property bool isActive: modelData && modelData.globalIndex === root.activeTabIndex
                width: isActive ? 28 : 22
                height: 22
                radius: 11
                anchors.verticalCenter: extPageDotsList.contentItem.verticalCenter
                color: isActive ? Theme.accent : (extDotMouse.containsMouse ? Theme.selection : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.90))
                border.color: isActive ? Theme.accent : (extDotMouse.containsMouse ? Theme.accent : Qt.rgba(255, 255, 255, 0.22))
                border.width: 1

                Behavior on width {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Text {
                    text: (index + 1).toString()
                    anchors.centerIn: parent
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.fontFamily
                    color: extDotItem.isActive ? Theme.background : Theme.foreground
                }

                MouseArea {
                    id: extDotMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.showTooltip(extDotItem, "Aba " + (index + 1) + ": " + (modelData ? modelData.title : ""))
                    onExited: root.hideTooltip()
                    onClicked: {
                        if (modelData) {
                            root.switchTab(modelData.globalIndex);
                            var tab = root.tabsModel.get(modelData.globalIndex);
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

            Behavior on contentX {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        // Rolagem com mouse sobre a barra externa de números alterna as abas do grupo
        WheelHandler {
            target: externalPageDotsStrip
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (root.activeGroupTabs && root.activeGroupTabs.length > 1) {
                    var count = root.activeGroupTabs.length;
                    var curGroupTabIdx = -1;
                    for (var k = 0; k < count; k++) {
                        if (root.activeGroupTabs[k].globalIndex === root.activeTabIndex) {
                            curGroupTabIdx = k;
                            break;
                        }
                    }
                    if (curGroupTabIdx === -1) curGroupTabIdx = 0;
                    var newGroupTabIdx = curGroupTabIdx;
                    if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                        newGroupTabIdx = (curGroupTabIdx - 1 + count) % count;
                    } else if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                        newGroupTabIdx = (curGroupTabIdx + 1) % count;
                    }
                    if (newGroupTabIdx !== curGroupTabIdx) {
                        var targetGlobal = root.activeGroupTabs[newGroupTabIdx].globalIndex;
                        root.switchTab(targetGlobal);
                        var tab = root.tabsModel.get(targetGlobal);
                        if (tab && tab.url && tab.url !== "about:blank") {
                            inputQuery.text = tab.url;
                        } else {
                            inputQuery.text = "";
                        }
                        inputQuery.selectAll();
                        extPageDotsList.positionViewAtIndex(newGroupTabIdx, ListView.Center);
                    }
                }
            }
        }
    }
    property var tabsModel: null
    property int activeTabIndex: 0

    signal openUrlInTab(string url)
    signal newTabRequested(string url, string workspace)
    signal newTabInGroupRequested(string url, string workspace, string tabGroup)
    signal switchTabRequested(int index)
    signal closeTabRequested(int index)
    signal webViewAction(string action)
    signal flipSplitRequested()

    function getGroupsForWorkspace(ws) {
        var dummy = root.groupsVersion;
        var list = [];
        if (root.workspaceGroups && root.workspaceGroups[ws] && Array.isArray(root.workspaceGroups[ws])) {
            list = root.workspaceGroups[ws].slice();
        }
        if (list.length === 0) {
            list = ["Geral"];
        }
        if (root.tabsModel) {
            for (var i = 0; i < root.tabsModel.count; i++) {
                var tab = root.tabsModel.get(i);
                if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal"))) {
                    var tg = tab.tabGroup || "Geral";
                    if (list.indexOf(tg) === -1) {
                        list.push(tg);
                    }
                }
            }
        }
        return list;
    }

    function getGroupSwitcherOptions(ws) {
        var options = ["Agora"];
        var groups = getGroupsForWorkspace(ws);
        for (var i = 0; i < groups.length; i++) {
            if (groups[i] !== "Agora") options.push(groups[i]);
        }
        return options;
    }

    function getVisibleGroupsForWorkspace(ws) {
        return root.activeGroupName === "Agora" ? ["Agora"] : getGroupsForWorkspace(ws);
    }

    function initializeSessionHistory() {
        var ids = [];
        if (root.tabsModel) {
            if (root.activeTabIndex >= 0 && root.activeTabIndex < root.tabsModel.count) {
                var activeTab = root.tabsModel.get(root.activeTabIndex);
                if (activeTab) ids.push(activeTab.tabId);
            }
            for (var i = root.tabsModel.count - 1; i >= 0; i--) {
                if (i === root.activeTabIndex) continue;
                var tab = root.tabsModel.get(i);
                if (tab) ids.push(tab.tabId);
            }
        }
        root.sessionRecentTabIds = ids;
        root.groupsVersion++;
    }

    function rememberSessionTab(tabIndex) {
        if (!root.tabsModel || tabIndex < 0 || tabIndex >= root.tabsModel.count) return;
        var tab = root.tabsModel.get(tabIndex);
        if (!tab) return;
        var id = tab.tabId;
        var ids = root.sessionRecentTabIds.slice();
        ids = ids.filter(function(existingId) { return existingId !== id; });
        ids.unshift(id);
        root.sessionRecentTabIds = ids;
        root.groupsVersion++;
    }

    function forgetSessionTab(tabIndex) {
        if (!root.tabsModel || tabIndex < 0 || tabIndex >= root.tabsModel.count) return;
        var tab = root.tabsModel.get(tabIndex);
        if (!tab) return;
        root.sessionRecentTabIds = root.sessionRecentTabIds.filter(function(id) { return id !== tab.tabId; });
        root.groupsVersion++;
    }

    function isSessionNowTab(tabId) {
        return root.sessionRecentTabIds.indexOf(tabId) !== -1;
    }

    function reorderSessionTab(sourceIndex, targetIndex, placeAfter) {
        if (!root.tabsModel || sourceIndex === targetIndex) return;
        var source = root.tabsModel.get(sourceIndex);
        var target = root.tabsModel.get(targetIndex);
        if (!source || !target) return;
        var ids = root.sessionRecentTabIds.slice();
        var from = ids.indexOf(source.tabId);
        var to = ids.indexOf(target.tabId);
        if (from < 0 || to < 0 || from === to) return;
        var destination = to + (placeAfter ? 1 : 0);
        if (from < destination) destination--;
        destination = Math.max(0, Math.min(ids.length - 1, destination));
        ids.splice(from, 1);
        ids.splice(destination, 0, source.tabId);
        root.sessionRecentTabIds = ids;
        root.groupsVersion++;
        bridge.saveSession(root.serializeSession());
    }

    function isGroupCollapsed(ws, groupName) {
        var dummy = root.groupsVersion;
        var key = ws + "::" + groupName;
        return !!root.collapsedGroups[key];
    }

    function toggleGroupCollapsed(ws, groupName) {
        var key = ws + "::" + groupName;
        var copy = Object.assign({}, root.collapsedGroups);
        copy[key] = !copy[key];
        root.collapsedGroups = copy;
        root.groupsVersion++;
    }

    function countTabsInGroup(ws, groupName) {
        if (!root.tabsModel) return 0;
        var c = 0;
        for (var i = 0; i < root.tabsModel.count; i++) {
            var tab = root.tabsModel.get(i);
            if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal"))) {
                var tg = tab.tabGroup || "Geral";
                if (tg === groupName) {
                    c++;
                }
            }
        }
        return c;
    }

    property var activeGroupTabs: {
        var dummy = root.groupsVersion;
        var actTab = root.activeTabIndex;
        var ws = root.activeWorkspace;
        var grp = root.activeGroupName;
        var tCount = root.tabsModel ? root.tabsModel.count : 0;
        return root.getTabsInActiveGroup();
    }

    function getTabsInActiveGroup() {
        var dummy = root.groupsVersion;
        if (!root.tabsModel) return [];
        if (root.activeGroupName === "Agora") {
            var recent = [];
            for (var r = 0; r < root.sessionRecentTabIds.length; r++) {
                var recentId = root.sessionRecentTabIds[r];
                for (var ri = 0; ri < root.tabsModel.count; ri++) {
                    var recentTab = root.tabsModel.get(ri);
                    if (recentTab && recentTab.tabId === recentId) {
                        recent.push({
                            globalIndex: ri,
                            title: recentTab.title || recentTab.url || "Nova Aba",
                            url: recentTab.url || ""
                        });
                        break;
                    }
                }
            }
            return recent;
        }
        var ws = root.activeWorkspace;
        var grp = root.activeGroupName || "Geral";
        var list = [];
        for (var i = 0; i < root.tabsModel.count; i++) {
            var tab = root.tabsModel.get(i);
            if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal"))) {
                var tg = tab.tabGroup || "Geral";
                if (tg === grp) {
                    list.push({
                        globalIndex: i,
                        title: tab.title || tab.url || "Nova Aba",
                        url: tab.url || ""
                    });
                }
            }
        }
        return list;
    }

    function ensureActiveGroup() {
        var grps = getGroupSwitcherOptions(root.activeWorkspace);
        if (grps.indexOf(root.activeGroupName) === -1) {
            root.activeGroupName = grps.length > 0 ? grps[0] : "Geral";
        }
    }

    function serializeSession() {
        var tabsArr = [];
        if (root.tabsModel) {
            for (var i = 0; i < root.tabsModel.count; i++) {
                var t = root.tabsModel.get(i);
                if (t && (t.url || t.title)) {
                    tabsArr.push({
                        tabId: t.tabId || (i + 1),
                        title: t.title || "",
                        url: t.url || "",
                        workspace: t.workspace || "Principal",
                        tabGroup: t.tabGroup || "Geral",
                        favicon: t.favicon || ""
                    });
                }
            }
        }
        var sess = {
            workspaces: root.workspaces,
            workspaceGroups: root.workspaceGroups,
            activeWorkspace: root.activeWorkspace,
            activeGroupName: root.activeGroupName,
            activeTabIndex: root.activeTabIndex,
            tabs: tabsArr
        };
        return JSON.stringify(sess);
    }

    function renameWorkspace(oldName, newName) {
        var trimmed = (newName || "").trim();
        if (!trimmed || trimmed === oldName) return;
        var idx = root.workspaces.indexOf(oldName);
        if (idx !== -1) {
            var list = root.workspaces.slice();
            list[idx] = trimmed;
            root.workspaces = list;
        }
        var grpCopy = Object.assign({}, root.workspaceGroups);
        if (grpCopy[oldName]) {
            grpCopy[trimmed] = grpCopy[oldName];
            delete grpCopy[oldName];
            root.workspaceGroups = grpCopy;
        }
        if (root.tabsModel) {
            for (var i = 0; i < root.tabsModel.count; i++) {
                var tab = root.tabsModel.get(i);
                if (tab && tab.workspace === oldName) {
                    root.tabsModel.setProperty(i, "workspace", trimmed);
                }
            }
        }
        if (root.activeWorkspace === oldName) {
            root.activeWorkspace = trimmed;
        }
        root.groupsVersion++;
        bridge.saveSession(serializeSession());
    }

    function deleteWorkspace(ws) {
        if (root.workspaces.length <= 1) return;
        if (root.tabsModel) {
            for (var i = root.tabsModel.count - 1; i >= 0; i--) {
                var tab = root.tabsModel.get(i);
                if (tab && tab.workspace === ws) {
                    root.closeTab(i);
                }
            }
        }
        var list = root.workspaces.filter(function(it) { return it !== ws; });
        root.workspaces = list;
        var grpCopy = Object.assign({}, root.workspaceGroups);
        delete grpCopy[ws];
        root.workspaceGroups = grpCopy;
        if (root.activeWorkspace === ws) {
            root.activeWorkspace = list[0];
        }
        root.ensureActiveGroup();
        root.groupsVersion++;
        bridge.saveSession(serializeSession());
    }

    function renameGroup(oldGrp, newGrp) {
        var trimmed = (newGrp || "").trim();
        if (!trimmed || trimmed === oldGrp) return;
        var ws = root.activeWorkspace;
        var grps = root.getGroupsForWorkspace(ws);
        var idx = grps.indexOf(oldGrp);
        if (idx !== -1) {
            grps[idx] = trimmed;
            var copy = Object.assign({}, root.workspaceGroups);
            copy[ws] = grps;
            root.workspaceGroups = copy;
        }
        if (root.tabsModel) {
            for (var i = 0; i < root.tabsModel.count; i++) {
                var tab = root.tabsModel.get(i);
                if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal")) && (tab.tabGroup === oldGrp || (!tab.tabGroup && oldGrp === "Geral"))) {
                    root.tabsModel.setProperty(i, "tabGroup", trimmed);
                }
            }
        }
        if (root.activeGroupName === oldGrp) {
            root.activeGroupName = trimmed;
        }
        root.groupsVersion++;
        bridge.saveSession(serializeSession());
    }

    function deleteGroup(grp) {
        var ws = root.activeWorkspace;
        var grps = root.getGroupsForWorkspace(ws);
        if (grps.length <= 1) return;
        var remaining = grps.filter(function(it) { return it !== grp; });
        var targetGrp = remaining[0] || "Geral";
        if (root.tabsModel) {
            for (var i = 0; i < root.tabsModel.count; i++) {
                var tab = root.tabsModel.get(i);
                if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal")) && (tab.tabGroup === grp)) {
                    root.tabsModel.setProperty(i, "tabGroup", targetGrp);
                }
            }
        }
        var copy = Object.assign({}, root.workspaceGroups);
        copy[ws] = remaining;
        root.workspaceGroups = copy;
        if (root.activeGroupName === grp) {
            root.activeGroupName = targetGrp;
        }
        root.groupsVersion++;
        bridge.saveSession(serializeSession());
    }

    function duplicateTab(idx) {
        if (!root.tabsModel || idx < 0 || idx >= root.tabsModel.count) return;
        var tab = root.tabsModel.get(idx);
        if (tab) {
            root.newTabInGroupRequested(tab.url, tab.workspace || "Principal", tab.tabGroup || "Geral");
        }
    }

    function reorderTab(sourceIndex, targetIndex, placeAfter) {
        if (!root.tabsModel || sourceIndex < 0 || targetIndex < 0
                || sourceIndex >= root.tabsModel.count || targetIndex >= root.tabsModel.count
                || sourceIndex === targetIndex) return;
        var source = root.tabsModel.get(sourceIndex);
        var target = root.tabsModel.get(targetIndex);
        if (!source || !target
                || (source.workspace || "Principal") !== (target.workspace || "Principal")
                || (source.tabGroup || "Geral") !== (target.tabGroup || "Geral")) return;

        var destination = targetIndex + (placeAfter ? 1 : 0);
        if (sourceIndex < destination) destination--;
        destination = Math.max(0, Math.min(root.tabsModel.count - 1, destination));
        if (sourceIndex === destination) return;

        function remapTabIndex(currentIndex) {
            if (currentIndex === sourceIndex) return destination;
            if (sourceIndex < destination && currentIndex > sourceIndex && currentIndex <= destination) return currentIndex - 1;
            if (destination < sourceIndex && currentIndex >= destination && currentIndex < sourceIndex) return currentIndex + 1;
            return currentIndex;
        }

        root.tabsModel.move(sourceIndex, destination, 1);
        root.activeTabIndex = remapTabIndex(root.activeTabIndex);
        root.splitTabIndex = remapTabIndex(root.splitTabIndex);
        root.groupsVersion++;
        bridge.saveSession(root.serializeSession());
    }

    function moveTabToGroup(tabIndex, targetGroupName) {
        if (!root.tabsModel || tabIndex < 0 || tabIndex >= root.tabsModel.count) return;
        var tab = root.tabsModel.get(tabIndex);
        if (!tab) return;
        if (targetGroupName === "Agora") {
            root.rememberSessionTab(tabIndex);
            root.activeGroupName = "Agora";
            return;
        }
        var curGroup = tab.tabGroup || "Geral";
        if (curGroup === targetGroupName) return;

        var ws = root.activeWorkspace;
        root.tabsModel.setProperty(tabIndex, "tabGroup", targetGroupName);
        root.tabsModel.setProperty(tabIndex, "workspace", ws);
        root.groupsVersion++;
        root.activeGroupName = targetGroupName;

        // Auto-expand target group if collapsed
        if (root.isGroupCollapsed(ws, targetGroupName)) {
            root.toggleGroupCollapsed(ws, targetGroupName);
        }

        bridge.saveSession(root.serializeSession());
    }

    function updateDragOverGroup(cardX, cardY) {
        if (!tabDragAvatar.isDragging) {
            root.dragOverGroupName = "";
            return;
        }
        var flickPt = launcherCard.mapToItem(tabsFlickable, cardX, cardY);
        // Auto scroll tabsFlickable when dragging tab near or beyond top/bottom
        if (flickPt.y > tabsFlickable.height - 35) {
            tabsFlickable.contentY = Math.min(tabsFlickable.contentHeight - tabsFlickable.height, tabsFlickable.contentY + 16);
        } else if (flickPt.y < 35) {
            tabsFlickable.contentY = Math.max(0, tabsFlickable.contentY - 16);
        }

        for (var i = 0; i < groupsColumn.children.length; i++) {
            var grpItem = groupsColumn.children[i];
            if (grpItem && grpItem.groupName) {
                var pt = launcherCard.mapToItem(grpItem, cardX, cardY);
                if (pt.x >= 0 && pt.x <= grpItem.width && pt.y >= 0 && pt.y <= grpItem.height) {
                    root.dragOverGroupName = grpItem.groupName;
                    return;
                }
            }
        }
        root.dragOverGroupName = "";
    }

    function checkDropOnGroup(cardX, cardY, tabIndex, sourceGroup) {
        if (tabIndex < 0) return;
        for (var i = 0; i < groupsColumn.children.length; i++) {
            var grpItem = groupsColumn.children[i];
            if (grpItem && grpItem.groupName) {
                var pt = launcherCard.mapToItem(grpItem, cardX, cardY);
                if (pt.x >= 0 && pt.x <= grpItem.width && pt.y >= 0 && pt.y <= grpItem.height) {
                    if (grpItem.groupName !== sourceGroup) {
                        root.moveTabToGroup(tabIndex, grpItem.groupName);
                    }
                    return;
                }
            }
        }
    }

    function updateGroupDragOver(cardX, cardY) {
        if (!groupDragAvatar.isDragging) {
            root.dragReorderTargetGroup = "";
            return;
        }
        var flickPt = launcherCard.mapToItem(tabsFlickable, cardX, cardY);
        // Auto scroll tabsFlickable when dragging group near top or bottom
        if (flickPt.y > tabsFlickable.height - 35) {
            tabsFlickable.contentY = Math.min(tabsFlickable.contentHeight - tabsFlickable.height, tabsFlickable.contentY + 16);
        } else if (flickPt.y < 35) {
            tabsFlickable.contentY = Math.max(0, tabsFlickable.contentY - 14);
        }

        for (var i = 0; i < groupsColumn.children.length; i++) {
            var grpItem = groupsColumn.children[i];
            if (grpItem && grpItem.groupName) {
                var pt = launcherCard.mapToItem(grpItem, cardX, cardY);
                if (pt.x >= 0 && pt.x <= grpItem.width && pt.y >= 0 && pt.y <= grpItem.height) {
                    if (grpItem.groupName !== groupDragAvatar.sourceGroup) {
                        root.dragReorderTargetGroup = grpItem.groupName;
                        return;
                    }
                }
            }
        }
        root.dragReorderTargetGroup = "";
    }

    function checkDropReorderGroup(cardX, cardY, sourceGroup) {
        for (var i = 0; i < groupsColumn.children.length; i++) {
            var grpItem = groupsColumn.children[i];
            if (grpItem && grpItem.groupName) {
                var pt = launcherCard.mapToItem(grpItem, cardX, cardY);
                if (pt.x >= 0 && pt.x <= grpItem.width && pt.y >= 0 && pt.y <= grpItem.height) {
                    if (grpItem.groupName !== sourceGroup) {
                        root.reorderGroups(sourceGroup, grpItem.groupName);
                    }
                    return;
                }
            }
        }
    }

    function reorderGroups(sourceGroup, targetGroup) {
        if (!sourceGroup || !targetGroup || sourceGroup === targetGroup) return;
        var ws = root.activeWorkspace;
        var current = root.getGroupsForWorkspace(ws).slice();
        var fromIdx = current.indexOf(sourceGroup);
        var toIdx = current.indexOf(targetGroup);
        if (fromIdx === -1 || toIdx === -1) return;

        current.splice(fromIdx, 1);
        current.splice(toIdx, 0, sourceGroup);

        var copy = Object.assign({}, root.workspaceGroups);
        copy[ws] = current;
        root.workspaceGroups = copy;
        root.groupsVersion++;

        bridge.saveSession(root.serializeSession());
    }

    function createNewGroupInActiveWorkspace() {
        var ws = root.activeWorkspace;
        var current = root.getGroupsForWorkspace(ws);
        var num = current.length + 1;
        var newGrp = "Grupo " + num;
        while (current.indexOf(newGrp) !== -1) {
            num++;
            newGrp = "Grupo " + num;
        }
        var copy = Object.assign({}, root.workspaceGroups);
        if (!copy[ws]) copy[ws] = ["Geral"];
        var wsList = copy[ws].slice();
        wsList.push(newGrp);
        copy[ws] = wsList;
        root.workspaceGroups = copy;
        root.groupsVersion++;
        root.activeGroupName = newGrp;

        bridge.saveSession(root.serializeSession());

        // Rola a lista para baixo para o novo grupo aparecer em foco
        scrollTabsToBottomTimer.restart();
    }

    function countTabsInWorkspace(ws) {
        if (!root.tabsModel) return 0;
        var c = 0;
        for (var i = 0; i < root.tabsModel.count; i++) {
            var tab = root.tabsModel.get(i);
            if (tab && (tab.workspace === ws || (!tab.workspace && ws === "Principal"))) {
                c++;
            }
        }
        return c;
    }

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

        // Qualquer domínio sem www (ex: google.com, youtube.com, globo.com, uol.com.br, reddit.com)
        if (text.indexOf(" ") === -1 && text.indexOf(".") !== -1) {
            var host = text.split("/")[0].split("?")[0].split("#")[0];
            var hostParts = host.split(".");
            var tld = hostParts[hostParts.length - 1].split(":")[0];
            if (tld && tld.length >= 2 && !tld.match(/[^a-zA-Z]/)) {
                // Se já tem subdomínio específico (ex: api.github.com, m.youtube.com, sub.domain.com)
                if (hostParts.length > 2 && hostParts[0] !== "www" && hostParts[hostParts.length - 2] !== "com" && hostParts[hostParts.length - 2] !== "org" && hostParts[hostParts.length - 2] !== "net") {
                    return "https://" + text;
                }
                // Prefixa com www. para garantir acesso direto a qualquer site sem falha de DNS
                if (!host.startsWith("www.")) {
                    return "https://www." + text;
                }
                return "https://" + text;
            }
        }

        // Fallback para pesquisa no Google
        return "https://www.google.com/search?q=" + encodeURIComponent(text);
    }

    function translateCurrentPage(targetLang) {
        if (!bridge.currentUrl || bridge.currentUrl.length === 0 || bridge.currentUrl === "about:blank") return;
        var lang = targetLang || "pt";
        root.translatePageRequested(lang);
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

        // 2. Open Tabs from Chrome / Chromium / Brave
        try {
            var openTabs = JSON.parse(bridge.openTabsJson || "[]");
            var otCount = 0;
            var qLowerOT = q.toLowerCase();
            for (var k = 0; k < openTabs.length && otCount < 5; k++) {
                var ot = openTabs[k];
                if ((ot.title && ot.title.toLowerCase().indexOf(qLowerOT) !== -1) || (ot.url && ot.url.toLowerCase().indexOf(qLowerOT) !== -1)) {
                    resultsModel.append({
                        isUrl: true,
                        title: "📂 Aba: " + (ot.title || ot.url),
                        url: ot.url
                    });
                    otCount++;
                }
            }
        } catch(e) {}

        // 3. Bookmarks from Chrome
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
            root.isSiteConfigExpanded = false;
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
                root.isSiteConfigExpanded = false;
                root.hideTooltip();
            }
        }
    }

    // Tooltip flutuante global para qualquer ícone/botão (nunca cortado por cards ou contêineres)
    Rectangle {
        id: globalHoverTooltip
        visible: root.hoverTooltipText.length > 0
        opacity: visible ? 1.0 : 0.0
        z: 999999
        height: 22
        width: tooltipLabel.implicitWidth + 16
        radius: 4
        color: Theme.surface
        border.color: Theme.accent
        border.width: 1

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Text {
            id: tooltipLabel
            anchors.centerIn: parent
            text: root.hoverTooltipText
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: true
            color: Theme.foreground
        }
    }
}
