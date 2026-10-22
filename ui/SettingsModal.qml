import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: bridge.settingsVisible
    anchors.fill: parent
    z: 999

    signal requestBitwardenUnlock()

    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    // Dimmed background backdrop
    Rectangle {
        anchors.fill: parent
        color: "#90000000"
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: bridge.settingsVisible = false
        }
    }

    // Modal Card
    Rectangle {
        id: card
        width: Math.min(740, parent.width - 48)
        height: Math.min(520, parent.height - 48)
        anchors.centerIn: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.activeBorder
        border.width: Theme.borderSize
        clip: true

        scale: root.visible ? 1.0 : 0.96
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        // Prevent clicks inside card from closing modal
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Current Active Section
        property string activeSection: "engine"

        // Config state loaded from bridge
        property var config: {
            try {
                return JSON.parse(bridge.configJson)
            } catch(e) {
                return {
                    default_engine: "chromium",
                    search_engine: "google",
                    home_url: "",
                    hardware_acceleration: true,
                    dark_mode: true,
                    zoom_level: 1.0,
                    theme_mode: "system",
                    language: "en-US",
                    bitwarden_enabled: false
                }
            }
        }

        property string currentThemeMode: (card.config && card.config.theme_mode) ? card.config.theme_mode : "system"
        property string currentLanguage: (card.config && card.config.language) ? card.config.language : "en-US"

        Connections {
            target: bridge
            function onConfigJsonChanged() {
                try {
                    card.config = JSON.parse(bridge.configJson);
                    card.currentThemeMode = (card.config && card.config.theme_mode) ? card.config.theme_mode : "system";
                    card.currentLanguage = (card.config && card.config.language) ? card.config.language : "en-US";
                } catch(e) {
                    card.config = {};
                }
            }
        }

        function updateConfig(key, value) {
            var c = {};
            try {
                c = JSON.parse(JSON.stringify(card.config || {}));
            } catch(e) {
                c = {};
            }
            c[key] = value;
            card.config = c;
            if (key === "theme_mode") {
                card.currentThemeMode = value;
            } else if (key === "language") {
                card.currentLanguage = value;
            }
            bridge.saveConfig(JSON.stringify(c));
        }

        Row {
            anchors.fill: parent

            // Left Rail
            Rectangle {
                width: 210
                height: parent.height
                color: Qt.rgba(0, 0, 0, 0.15)

                Rectangle {
                    width: 1
                    height: parent.height
                    anchors.right: parent.right
                    color: Theme.border
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    // App Title
                    Row {
                        spacing: 10
                        bottomPadding: 14

                        Rectangle {
                            width: 30
                            height: 30
                            radius: root.itemRadius
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Ω"
                                anchors.centerIn: parent
                                color: Theme.background
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "Focus"
                                color: Theme.foreground
                                font.pixelSize: Theme.fontTitle
                                font.bold: true
                            }
                            Text {
                                text: "Configurações"
                                color: Theme.dimForeground
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Navigation items
                    Repeater {
                        model: [
                            { id: "engine", label: "Motor Web", glyph: "globe" },
                            { id: "search", label: "Pesquisa", glyph: "search" },
                            { id: "languages", label: "Idiomas", glyph: "type" },
                            { id: "sync", label: "Conta & Sync", glyph: "lock" },
                            { id: "passwords", label: "Senhas", glyph: "key" },
                            { id: "extensions", label: "Extensões", glyph: "archive-out" },
                            { id: "appearance", label: "Aparência", glyph: "contrast" },
                            { id: "about", label: "Sobre", glyph: "keyboard" }
                        ]

                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: root.itemRadius
                            color: card.activeSection === modelData.id ? Theme.selection : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                            border.color: card.activeSection === modelData.id ? Theme.accent : "transparent"
                            border.width: 1

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.activeSection = modelData.id
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 10

                                Glyph {
                                    name: modelData.glyph
                                    size: 14
                                    color: card.activeSection === modelData.id ? Theme.accent : Theme.dimForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.label
                                    color: card.activeSection === modelData.id ? Theme.foreground : Theme.dimForeground
                                    font.pixelSize: Theme.fontBody
                                    font.bold: card.activeSection === modelData.id
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Right Pane Content
            Rectangle {
                width: parent.width - 210
                height: parent.height
                color: "transparent"

                // Close Button Top Right
                Rectangle {
                    width: 28
                    height: 28
                    radius: root.itemRadius
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 14
                    color: closeMouse.containsMouse ? Theme.selection : "transparent"
                    border.color: closeMouse.containsMouse ? Theme.accent : "transparent"
                    border.width: 1
                    z: 10

                    Text {
                        text: "✕"
                        color: Theme.foreground
                        anchors.centerIn: parent
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bridge.settingsVisible = false
                    }
                }

                // Section 1: Motor Web (Chromium vs Firefox)
                Item {
                    id: paneEngine
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "engine"

                    Column {
                        spacing: 16
                        width: parent.width

                        Text {
                            text: "Motor de Renderização"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "O Focus utiliza QtWebEngine (Blink/V8) embutido nativamente sem bordas ou poluição visual. Você também pode integrar com o Gecko do Firefox/Zen."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Engine Option 1: Chromium (Blink)
                        Rectangle {
                            width: parent.width
                            height: 68
                            radius: root.itemRadius
                            color: bridge.currentEngine === "chromium" ? Theme.selection : Qt.rgba(1, 1, 1, 0.02)
                            border.color: bridge.currentEngine === "chromium" ? Theme.accent : Theme.border
                            border.width: bridge.currentEngine === "chromium" ? 2 : 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bridge.currentEngine = "chromium";
                                    card.updateConfig("default_engine", "chromium");
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Glyph {
                                    name: "globe"
                                    size: 22
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 3
                                    Text {
                                        text: "Chromium (QtWebEngine - Blink/V8)"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Embarcado nativo na janela, aceleração de hardware e alta velocidade."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }
                        }

                        // Engine Option 2: Firefox / Zen
                        Rectangle {
                            width: parent.width
                            height: 68
                            radius: root.itemRadius
                            color: bridge.currentEngine === "firefox" ? Theme.selection : Qt.rgba(1, 1, 1, 0.02)
                            border.color: bridge.currentEngine === "firefox" ? Theme.accent : Theme.border
                            border.width: bridge.currentEngine === "firefox" ? 2 : 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bridge.currentEngine = "firefox";
                                    card.updateConfig("default_engine", "firefox");
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Glyph {
                                    name: "terminal"
                                    size: 22
                                    color: Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 3
                                    Text {
                                        text: "Firefox / Zen Browser (Gecko)"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Alterna páginas para a instância Gecko/Zen com máxima privacidade."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 2: Pesquisa (Google, DuckDuckGo, etc.)
                Item {
                    id: paneSearch
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "search"

                    Column {
                        spacing: 14
                        width: parent.width

                        Text {
                            text: "Motor de Pesquisa Padrão"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Selecione o motor utilizado ao digitar termos de pesquisa no lançador."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                        }

                        Repeater {
                            model: [
                                { id: "google", label: "Google Search", desc: "https://www.google.com/search?q=" },
                                { id: "duckduckgo", label: "DuckDuckGo", desc: "https://duckduckgo.com/?q=" },
                                { id: "brave", label: "Brave Search", desc: "https://search.brave.com/search?q=" },
                                { id: "bing", label: "Microsoft Bing", desc: "https://www.bing.com/search?q=" }
                            ]

                            Rectangle {
                                width: parent.width
                                height: 48
                                radius: root.itemRadius
                                color: (card.config.search_engine || "google") === modelData.id ? Theme.selection : Qt.rgba(1, 1, 1, 0.02)
                                border.color: (card.config.search_engine || "google") === modelData.id ? Theme.accent : Theme.border
                                border.width: 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: card.updateConfig("search_engine", modelData.id)
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: root.itemRadius
                                        border.color: Theme.accent
                                        border.width: 1.5
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: Math.max(1, root.itemRadius - 1)
                                            color: Theme.accent
                                            anchors.centerIn: parent
                                            visible: (card.config.search_engine || "google") === modelData.id
                                        }
                                    }

                                    Column {
                                        Text { text: modelData.label; color: Theme.foreground; font.pixelSize: Theme.fontBody; font.bold: true }
                                        Text { text: modelData.desc; color: Theme.dimForeground; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }

                        // Tradução de Páginas
                        Rectangle {
                            width: parent.width
                            height: 52
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Theme.border
                            border.width: 1

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12

                                Glyph {
                                    name: "type"
                                    size: 16
                                    color: (card.config.enable_translation !== false) ? Theme.accent : Theme.dimForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 2
                                    Text {
                                        text: "Botão de Tradução no Lançador"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Exibir o botão de tradução rápida à direita da barra de endereços."
                                        color: Theme.dimForeground
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            // Switch
                            Rectangle {
                                width: 40
                                height: 22
                                radius: 11
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: (card.config.enable_translation !== false) ? Theme.accent : Qt.rgba(1, 1, 1, 0.1)

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: (card.config.enable_translation !== false) ? Theme.background : Theme.dimForeground
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (card.config.enable_translation !== false) ? 21 : 3

                                    Behavior on x {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var current = card.config.enable_translation !== false;
                                        card.updateConfig("enable_translation", !current);
                                    }
                                }
                            }
                        }
                    }
                }

                // Section: Idiomas (Languages)
                Item {
                    id: paneLanguages
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "languages"

                    Column {
                        spacing: 14
                        width: parent.width

                        Text {
                            text: "Idiomas do Navegador"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Selecione o idioma preferencial para páginas da web e requisições HTTP (Accept-Language). O Focus utiliza o Inglês (English) como idioma padrão."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Lista com rolagem
                        Flickable {
                            width: parent.width
                            height: 320
                            contentWidth: width
                            contentHeight: langColumn.height
                            clip: true

                            Column {
                                id: langColumn
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: [
                                        { code: "en-US", name: "English (US)", nativeName: "English (United States)", desc: "Idioma Padrão do Navegador (Default)", flag: "🇺🇸" },
                                        { code: "pt-BR", name: "Português (Brasil)", nativeName: "Português Brasileiro", desc: "Suporte completo e termos em português", flag: "🇧🇷" },
                                        { code: "es-ES", name: "Español", nativeName: "Español Internacional", desc: "Castellano / América Latina", flag: "🇪🇸" },
                                        { code: "fr-FR", name: "Français", nativeName: "Français (France)", desc: "Français standard", flag: "🇫🇷" },
                                        { code: "de-DE", name: "Deutsch", nativeName: "Deutsch (Deutschland)", desc: "Standarddeutsch", flag: "🇩🇪" },
                                        { code: "it-IT", name: "Italiano", nativeName: "Italiano (Italia)", desc: "Italiano standard", flag: "🇮🇹" },
                                        { code: "ja-JP", name: "日本語", nativeName: "日本語 (Japanese)", desc: "Nihongo (Japan)", flag: "🇯🇵" },
                                        { code: "zh-CN", name: "简体中文", nativeName: "中文 (Chinese)", desc: "Mandarin Simplified", flag: "🇨🇳" }
                                    ]

                                    Rectangle {
                                        width: langColumn.width
                                        height: 48
                                        radius: root.itemRadius
                                        color: card.currentLanguage === modelData.code ? Theme.selection : (langMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.02))
                                        border.color: card.currentLanguage === modelData.code ? Theme.accent : Theme.border
                                        border.width: card.currentLanguage === modelData.code ? 2 : 1

                                        MouseArea {
                                            id: langMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                card.updateConfig("language", modelData.code);
                                            }
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                text: modelData.flag
                                                font.pixelSize: 18
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2
                                                width: parent.width - 90

                                                Row {
                                                    spacing: 8
                                                    Text {
                                                        text: modelData.name
                                                        color: Theme.foreground
                                                        font.bold: true
                                                        font.pixelSize: 13
                                                    }
                                                    Text {
                                                        text: "• " + modelData.nativeName
                                                        color: Theme.dimForeground
                                                        font.pixelSize: 11
                                                    }
                                                    Rectangle {
                                                        height: 16
                                                        width: 54
                                                        radius: 8
                                                        color: Theme.accent
                                                        visible: modelData.code === "en-US"
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Text {
                                                            text: "PADRÃO"
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                            color: Theme.background
                                                            anchors.centerIn: parent
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: modelData.desc
                                                    color: Theme.dimForeground
                                                    font.pixelSize: 11
                                                }
                                            }

                                            Glyph {
                                                name: "check"
                                                size: 14
                                                color: Theme.accent
                                                visible: card.currentLanguage === modelData.code
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 3: Sincronização & Conta Google
                Item {
                    id: paneSync
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "sync"

                    Column {
                        spacing: 16
                        width: parent.width

                        Text {
                            text: "Conta Google & Sincronização"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Suporte a login nos serviços Google (Gmail, YouTube, Drive) com cookies e sessões persistidos em disco."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Google Account Card
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Theme.border
                            border.width: 1

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Glyph {
                                    name: "lock"
                                    size: 20
                                    color: Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 2
                                    Text {
                                        text: "Login na Conta Google"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Abra a autenticação do Google para sincronizar suas sessões."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }

                            Rectangle {
                                width: 100
                                height: 30
                                radius: root.itemRadius
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.accent

                                Text {
                                    text: "Login"
                                    color: Theme.background
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        bridge.settingsVisible = false;
                                        launcher.openUrlInTab("https://accounts.google.com");
                                    }
                                }
                            }
                        }

                        // Chrome Sync Card
                        Rectangle {
                            width: parent.width
                            height: 64
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Theme.border
                            border.width: 1

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Glyph {
                                    name: "refresh"
                                    size: 20
                                    color: Theme.foreground
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 2
                                    Text {
                                        text: "Importar Favoritos & Histórico"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Sincroniza os favoritos locais do Google Chrome/Chromium para o lançador."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }

                            Rectangle {
                                width: 100
                                height: 30
                                radius: root.itemRadius
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.selection
                                border.color: Theme.accent
                                border.width: 1

                                Text {
                                    text: "Sincronizar"
                                    color: Theme.foreground
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bridge.syncChrome()
                                }
                            }
                        }
                    }
                }

                // Section: Senhas & Logins Salvas no PC
                Item {
                    id: panePasswords
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "passwords"

                    property var passwordsList: {
                        try {
                            return JSON.parse(bridge.passwordsJson || "[]")
                        } catch(e) {
                            return []
                        }
                    }

                    property bool showAddForm: false

                    Column {
                        spacing: 14
                        width: parent.width

                        Row {
                            width: parent.width
                            spacing: 12

                            Column {
                                width: parent.width - 245
                                spacing: 4

                                Text {
                                    text: "Senhas & Logins no PC"
                                    color: Theme.foreground
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                Text {
                                    text: "Cofre soberano salvo no seu computador (~/.config/focus/passwords.json). Sessões permanecem salvas em cookies persistentes."
                                    color: Theme.dimForeground
                                    font.pixelSize: Theme.fontCaption
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // Botão Adicionar Conta
                            Rectangle {
                                width: 105
                                height: 32
                                radius: root.itemRadius
                                color: Theme.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Glyph { name: "plus"; size: 12; color: Theme.background; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Nova Senha"; color: Theme.background; font.bold: true; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panePasswords.showAddForm = !panePasswords.showAddForm
                                }
                            }

                            // Botão Importar CSV
                            Rectangle {
                                width: 115
                                height: 32
                                radius: root.itemRadius
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Theme.border
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Glyph { name: "download"; size: 12; color: Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Importar CSV"; color: Theme.foreground; font.bold: true; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var defaultPath = "/home/renato/Downloads/Chrome Passwords.csv";
                                        var count = bridge.importPasswordsFromCsv(defaultPath);
                                        if (count < 0) {
                                            importStatusText.text = "Para importar: no Chrome vá em 'Gerenciador de senhas > Exportar' e salve em Downloads/Chrome Passwords.csv";
                                        } else {
                                            importStatusText.text = "Importadas " + count + " senhas com sucesso do Chrome!";
                                        }
                                        importStatusTimer.restart();
                                    }
                                }
                            }
                        }

                        Text {
                            id: importStatusText
                            text: ""
                            color: Theme.accent
                            font.pixelSize: 11
                            visible: text.length > 0
                        }

                        // Card de Integração com o Bitwarden (Gerenciador de Chaves Padrão)
                        Rectangle {
                            width: parent.width
                            height: 66
                            radius: root.itemRadius
                            color: (card.config && card.config.bitwarden_enabled) ? Theme.selection : Qt.rgba(1, 1, 1, 0.03)
                            border.color: (card.config && card.config.bitwarden_enabled) ? Theme.accent : Theme.border
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Rectangle {
                                    width: 38
                                    height: 38
                                    radius: root.itemRadius
                                    color: (card.config && card.config.bitwarden_enabled) ? Theme.accent : Qt.rgba(1, 1, 1, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Glyph {
                                        name: "shield"
                                        size: 18
                                        color: (card.config && card.config.bitwarden_enabled) ? Theme.background : Theme.foreground
                                        anchors.centerIn: parent
                                    }
                                }

                                Column {
                                    width: parent.width - 270
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Row {
                                        spacing: 8
                                        Text {
                                            text: "Bitwarden (Gerenciador Padrão)"
                                            color: Theme.foreground
                                            font.bold: true
                                            font.pixelSize: 13
                                            font.family: Theme.fontFamily
                                        }

                                        Rectangle {
                                            height: 16
                                            width: 58
                                            radius: 8
                                            color: bridge.isBitwardenInstalled() ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(0.8, 0.2, 0.2, 0.15)
                                            border.color: bridge.isBitwardenInstalled() ? Theme.green : Theme.red
                                            border.width: 1
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: bridge.isBitwardenInstalled() ? "Instalado" : "Não achado"
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.family: Theme.fontFamily
                                                color: bridge.isBitwardenInstalled() ? Theme.green : Theme.red
                                                anchors.centerIn: parent
                                            }
                                        }

                                        Rectangle {
                                            height: 16
                                            width: bridge.bitwardenUnlocked ? 82 : 68
                                            radius: 8
                                            color: bridge.bitwardenUnlocked ? Qt.rgba(0.2, 0.8, 0.4, 0.2) : Qt.rgba(0.8, 0.6, 0.2, 0.2)
                                            border.color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                                            border.width: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: bridge.isBitwardenInstalled()

                                            Text {
                                                text: bridge.bitwardenUnlocked ? "✓ Desbloqueado" : "🔒 Bloqueado"
                                                font.pixelSize: 9
                                                font.bold: true
                                                font.family: Theme.fontFamily
                                                color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
                                                anchors.centerIn: parent
                                            }
                                        }
                                    }

                                    Text {
                                        text: bridge.bitwardenUnlocked
                                            ? "Cofre ativo no Focus. Autopreenchimento e salvamento automático estilo Google funcionam nativamente."
                                            : ((card.config && card.config.bitwarden_enabled)
                                                ? "Ativo. Desbloqueie com sua Senha Mestra para preencher e salvar credenciais nas páginas."
                                                : "Ative para utilizar o Bitwarden integrado como seu gerenciador padrão de senhas.")
                                        color: Theme.dimForeground
                                        font.pixelSize: 11
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    // Botão Desbloquear / Bloquear
                                    Rectangle {
                                        width: 80
                                        height: 26
                                        radius: root.itemRadius
                                        color: lockToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: Theme.border
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: (card.config && card.config.bitwarden_enabled) && bridge.isBitwardenInstalled()

                                        Text {
                                            text: bridge.bitwardenUnlocked ? "Bloquear" : "Desbloquear"
                                            color: bridge.bitwardenUnlocked ? Theme.dimForeground : Theme.accent
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.family: Theme.fontFamily
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: lockToggleMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (bridge.bitwardenUnlocked) {
                                                    bridge.lockBitwarden();
                                                } else {
                                                    root.requestBitwardenUnlock();
                                                }
                                            }
                                        }
                                    }

                                    // Botão Abrir App Desktop
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: root.itemRadius
                                        color: openBwMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                                        border.color: Theme.border
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        Glyph {
                                            name: "key"
                                            size: 13
                                            color: Theme.foreground
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: openBwMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: bridge.openBitwarden()
                                        }
                                    }

                                    // Switch Toggle Ativar/Desativar
                                    Rectangle {
                                        width: 48
                                        height: 24
                                        radius: 12
                                        color: (card.config && card.config.bitwarden_enabled) ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: (card.config && card.config.bitwarden_enabled) ? Theme.background : Theme.foreground
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: (card.config && card.config.bitwarden_enabled) ? (parent.width - width - 3) : 3

                                            Behavior on x {
                                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var cur = (card.config && card.config.bitwarden_enabled) ? true : false;
                                                card.updateConfig("bitwarden_enabled", !cur);
                                                if (!cur && !bridge.bitwardenUnlocked) {
                                                    root.requestBitwardenUnlock();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Formulário Inline para adicionar senha
                        Rectangle {
                            width: parent.width
                            height: panePasswords.showAddForm ? 90 : 0
                            visible: height > 0
                            clip: true
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Theme.accent
                            border.width: 1

                            Behavior on height {
                                NumberAnimation { duration: 150 }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Row {
                                    spacing: 8
                                    width: parent.width

                                    // Input Site
                                    Rectangle {
                                        width: (parent.width - 100) / 3
                                        height: 30
                                        radius: root.itemRadius
                                        color: Theme.surface
                                        border.color: Theme.border
                                        border.width: 1

                                        TextInput {
                                            id: siteInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: Theme.foreground
                                            font.pixelSize: 11
                                            clip: true
                                            Text {
                                                text: "Site (ex: github.com)"
                                                color: Theme.dimForeground
                                                font.pixelSize: 11
                                                visible: !siteInput.text
                                            }
                                        }
                                    }

                                    // Input Usuário
                                    Rectangle {
                                        width: (parent.width - 100) / 3
                                        height: 30
                                        radius: root.itemRadius
                                        color: Theme.surface
                                        border.color: Theme.border
                                        border.width: 1

                                        TextInput {
                                            id: userInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: Theme.foreground
                                            font.pixelSize: 11
                                            clip: true
                                            Text {
                                                text: "Usuário / Email"
                                                color: Theme.dimForeground
                                                font.pixelSize: 11
                                                visible: !userInput.text
                                            }
                                        }
                                    }

                                    // Input Senha
                                    Rectangle {
                                        width: (parent.width - 100) / 3
                                        height: 30
                                        radius: root.itemRadius
                                        color: Theme.surface
                                        border.color: Theme.border
                                        border.width: 1

                                        TextInput {
                                            id: passInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            color: Theme.foreground
                                            font.pixelSize: 11
                                            echoMode: TextInput.Password
                                            clip: true
                                            Text {
                                                text: "Senha"
                                                color: Theme.dimForeground
                                                font.pixelSize: 11
                                                visible: !passInput.text
                                            }
                                        }
                                    }

                                    // Botão Salvar
                                    Rectangle {
                                        width: 80
                                        height: 30
                                        radius: root.itemRadius
                                        color: Theme.green
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            text: "Salvar"
                                            color: Theme.background
                                            font.bold: true
                                            font.pixelSize: 11
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (siteInput.text && passInput.text) {
                                                    bridge.saveCredential(siteInput.text, userInput.text, passInput.text);
                                                    siteInput.text = "";
                                                    userInput.text = "";
                                                    passInput.text = "";
                                                    panePasswords.showAddForm = false;
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "As credenciais são salvas localmente no computador em ~/.config/focus/passwords.json"
                                    color: Theme.dimForeground
                                    font.pixelSize: 10
                                }
                            }
                        }

                        // Lista de Senhas Salvas
                        Rectangle {
                            width: parent.width
                            height: 250
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.02)
                            border.color: Theme.border
                            border.width: 1
                            clip: true

                            ListView {
                                id: passListView
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                clip: true
                                model: panePasswords.passwordsList

                                delegate: Rectangle {
                                    width: passListView.width
                                    height: 38
                                    radius: root.itemRadius
                                    color: pMouse.containsMouse ? Theme.selection : "transparent"

                                    property bool revealed: false

                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 12

                                        Glyph {
                                            name: "globe"
                                            size: 13
                                            color: Theme.accent
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: modelData.domain || modelData.url
                                            color: Theme.foreground
                                            font.bold: true
                                            font.pixelSize: 12
                                            width: 140
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: modelData.username || "(Sem usuário)"
                                            color: Theme.dimForeground
                                            font.pixelSize: 12
                                            width: 160
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: revealed ? modelData.password : "••••••••••••"
                                            color: revealed ? Theme.foreground : Theme.dimForeground
                                            font.pixelSize: 12
                                            width: 120
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        // Olho (revelar senha)
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: root.itemRadius
                                            color: eyeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Glyph {
                                                name: revealed ? "eye-off" : "eye"
                                                size: 13
                                                color: Theme.dimForeground
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: eyeMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: revealed = !revealed
                                            }
                                        }

                                        // Copiar senha
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: root.itemRadius
                                            color: copyMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Glyph {
                                                name: "copy"
                                                size: 13
                                                color: Theme.dimForeground
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: copyMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    copyHelper.text = modelData.password;
                                                    copyHelper.selectAll();
                                                    copyHelper.copy();
                                                }
                                            }
                                        }

                                        // Apagar senha
                                        Rectangle {
                                            width: 24
                                            height: 24
                                            radius: root.itemRadius
                                            color: delMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Glyph {
                                                name: "trash"
                                                size: 13
                                                color: delMouse.containsMouse ? Theme.red : Theme.dimForeground
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: delMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    bridge.deleteCredential(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Empty state
                            Text {
                                anchors.centerIn: parent
                                text: "Nenhuma credencial salva ainda.\nClique em 'Nova Senha' ou importe do Chrome."
                                color: Theme.dimForeground
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                visible: panePasswords.passwordsList.length === 0
                            }

                            TextInput {
                                id: copyHelper
                                visible: false
                            }
                        }
                    }
                }

                // Section: Extensões do Google Chrome
                Item {
                    id: paneExtensions
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "extensions"

                    property var extensionsList: []

                    function refreshExtensions() {
                        try {
                            paneExtensions.extensionsList = JSON.parse(bridge.extensionsJson) || [];
                        } catch(e) {
                            paneExtensions.extensionsList = [];
                        }
                    }

                    Component.onCompleted: refreshExtensions()

                    Connections {
                        target: bridge
                        function onExtensionsChanged() {
                            paneExtensions.refreshExtensions();
                        }
                    }

                    Column {
                        spacing: 16
                        width: parent.width
                        height: parent.height

                        Row {
                            width: parent.width
                            spacing: 12

                            Column {
                                width: parent.width - 150
                                spacing: 4

                                Text {
                                    text: "Extensões do Google Chrome"
                                    color: Theme.foreground
                                    font.pixelSize: 18
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                }

                                Text {
                                    text: "Suporte nativo a extensões Chromium/Chrome (.config/google-chrome e .config/chromium)."
                                    color: Theme.dimForeground
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                }
                            }

                            // Botão Recarregar
                            Rectangle {
                                width: 140
                                height: 32
                                radius: root.itemRadius
                                color: reloadExtMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                                border.color: Theme.accent
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Glyph { name: "archive-out"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: "Sincronizar"
                                        color: Theme.accent
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: reloadExtMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        bridge.loadChromeExtensions();
                                        paneExtensions.refreshExtensions();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }

                        // Lista de extensões
                        ListView {
                            width: parent.width
                            height: parent.height - 80
                            clip: true
                            spacing: 8
                            model: paneExtensions.extensionsList

                            delegate: Rectangle {
                                width: parent.width
                                height: 60
                                radius: root.itemRadius
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.color: Theme.border
                                border.width: 1

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 12

                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: root.itemRadius
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Glyph {
                                            name: "archive-out"
                                            size: 18
                                            color: Theme.accent
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Column {
                                        width: parent.width - 130
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 3

                                        Row {
                                            spacing: 8
                                            Text {
                                                text: modelData.name || modelData.id
                                                color: Theme.foreground
                                                font.bold: true
                                                font.pixelSize: 13
                                                font.family: Theme.fontFamily
                                            }

                                            Rectangle {
                                                height: 16
                                                width: 48
                                                radius: 8
                                                color: Qt.rgba(0.2, 0.8, 0.4, 0.15)
                                                border.color: Theme.green
                                                border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    text: "Ativa"
                                                    font.pixelSize: 9
                                                    font.bold: true
                                                    font.family: Theme.fontFamily
                                                    color: Theme.green
                                                    anchors.centerIn: parent
                                                }
                                            }
                                        }

                                        Text {
                                            text: modelData.description || modelData.path
                                            color: Theme.dimForeground
                                            font.pixelSize: 11
                                            font.family: Theme.fontFamily
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Nenhuma extensão do Chrome encontrada.\nAs extensões instaladas no Google Chrome e Chromium são carregadas automaticamente."
                                color: Theme.dimForeground
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                visible: paneExtensions.extensionsList.length === 0
                            }
                        }
                    }
                }

                // Section 4: Aparência (Omarchy Theme)
                Item {
                    id: paneAppearance
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "appearance"

                    Column {
                        spacing: 16
                        width: parent.width

                        Text {
                            text: "Aparência & Tema"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Escolha o modo visual do Focus. Você pode seguir o tema do sistema Omarchy ou forçar o modo escuro ou claro."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // 3 Opções: Sistema, Escuro, Claro
                        Row {
                            spacing: 12
                            width: parent.width

                            Repeater {
                                model: [
                                    { id: "system", label: "Sistema", desc: "Segue o tema Omarchy", glyph: "monitor" },
                                    { id: "dark", label: "Escuro", desc: "Tons escuros elegantes", glyph: "moon" },
                                    { id: "light", label: "Claro", desc: "Alta luminosidade e clareza", glyph: "sun" }
                                ]

                                Rectangle {
                                    width: (paneAppearance.width - 24) / 3
                                    height: 90
                                    radius: root.itemRadius
                                    color: card.currentThemeMode === modelData.id ? Theme.selection : Qt.rgba(1, 1, 1, 0.02)
                                    border.color: card.currentThemeMode === modelData.id ? Theme.accent : Theme.border
                                    border.width: card.currentThemeMode === modelData.id ? 2 : 1

                                    MouseArea {
                                        id: modeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            card.updateConfig("theme_mode", modelData.id);
                                        }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        width: parent.width - 20

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 8

                                            Glyph {
                                                name: modelData.glyph
                                                size: 16
                                                color: card.currentThemeMode === modelData.id ? Theme.accent : Theme.foreground
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.label
                                                color: Theme.foreground
                                                font.bold: true
                                                font.pixelSize: 13
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Glyph {
                                                name: "check"
                                                size: 13
                                                color: Theme.accent
                                                visible: card.currentThemeMode === modelData.id
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Text {
                                            text: modelData.desc
                                            color: Theme.dimForeground
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        // Theme Info Card
                        Rectangle {
                            width: parent.width
                            height: 125
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Theme.border
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8

                                Row {
                                    spacing: 12
                                    Text { text: "Modo Atual Ativo:"; color: Theme.dimForeground; font.pixelSize: 12; width: 180 }
                                    Text { text: card.currentThemeMode === "system" ? ("Sistema (" + Theme.mode + ")") : ((card.currentThemeMode === "dark") ? "Escuro Forçado" : "Claro Forçado"); color: Theme.accent; font.bold: true; font.pixelSize: 12 }
                                }

                                Row {
                                    spacing: 12
                                    Text { text: "Arredondamento dos Cantos:"; color: Theme.dimForeground; font.pixelSize: 12; width: 180 }
                                    Text { text: Theme.cornerRadius + "px (Automático via Hyprland)"; color: Theme.foreground; font.bold: true; font.pixelSize: 12 }
                                }

                                Row {
                                    spacing: 12
                                    Text { text: "Espessura do Contorno:"; color: Theme.dimForeground; font.pixelSize: 12; width: 180 }
                                    Text { text: Theme.borderSize + "px"; color: Theme.foreground; font.bold: true; font.pixelSize: 12 }
                                }

                                Row {
                                    spacing: 12
                                    Text { text: "Seleção de Texto nas Páginas:"; color: Theme.dimForeground; font.pixelSize: 12; width: 180 }
                                    Text { text: "Injetada na cor de destaque (" + Theme.accent + ") em tempo real"; color: Theme.accent; font.bold: true; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                }

                // Section 5: Sobre Focus
                Item {
                    id: paneAbout
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "about"

                    Column {
                        spacing: 14
                        width: parent.width

                        Text {
                            text: "Sobre o Focus"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Navegador desktop minimalista com tela 100% limpa, ilha de comando unificada e motor WebEngine Chromium nativo integrado ao ecossistema Omarchy."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            height: 140
                            radius: root.itemRadius
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.color: Theme.border
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 7

                                Text { text: "Atalhos Rápidos de Teclado:"; color: Theme.foreground; font.bold: true; font.pixelSize: 12 }
                                Text { text: "• Espaço / Alt+Espaço: Abrir o lançador superior"; color: Theme.dimForeground; font.pixelSize: 11 }
                                Text { text: "• Ctrl+T: Nova aba (mantém o lançador aberto)"; color: Theme.dimForeground; font.pixelSize: 11 }
                                Text { text: "• Ctrl+L: Abrir barra de digitação rápida"; color: Theme.dimForeground; font.pixelSize: 11 }
                                Text { text: "• F12: Abrir/fechar Chrome DevTools nativo"; color: Theme.dimForeground; font.pixelSize: 11 }
                                Text { text: "• Esc / Clique fora: Fechar o lançador expandido"; color: Theme.dimForeground; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
