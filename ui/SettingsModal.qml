import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: bridge.settingsVisible
    anchors.fill: parent
    z: 999

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
        width: 680
        height: 500
        anchors.centerIn: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.border
        border.width: 1

        scale: root.visible ? 1.0 : 0.95
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180 }
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
                    home_url: "https://www.google.com",
                    hardware_acceleration: true,
                    dark_mode: true,
                    zoom_level: 1.0
                }
            }
        }

        function updateConfig(key, value) {
            var c = card.config;
            c[key] = value;
            card.config = c;
            bridge.saveConfig(JSON.stringify(c));
        }

        Row {
            anchors.fill: parent

            // Left Rail
            Rectangle {
                width: 200
                height: parent.height
                color: Theme.surfaceVariant
                radius: Theme.cornerRadius

                // Mask right corners
                Rectangle {
                    width: 10
                    height: parent.height
                    anchors.right: parent.right
                    color: Theme.surfaceVariant
                }

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
                        spacing: 8
                        bottomPadding: 16

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 0
                            color: Theme.accent

                            Text {
                                text: "Ω"
                                anchors.centerIn: parent
                                color: Theme.background
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Column {
                            Text {
                                text: "Focus"
                                color: Theme.foreground
                                font.pixelSize: Theme.fontTitle
                                font.bold: true
                            }
                            Text {
                                text: "Configurações"
                                color: Theme.dimForeground
                                font.pixelSize: Theme.fontCaption
                            }
                        }
                    }

                    // Navigation items
                    Repeater {
                        model: [
                            { id: "engine", label: "Motor Web", icon: "🌐" },
                            { id: "search", label: "Pesquisa", icon: "🔍" },
                            { id: "sync", label: "Conta & Sync", icon: "🔄" },
                            { id: "appearance", label: "Aparência", icon: "🎨" },
                            { id: "about", label: "Sobre", icon: "ℹ️" }
                        ]

                        Rectangle {
                            width: 172
                            height: 38
                            radius: 0
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
                                anchors.leftMargin: 12
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 14
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
                width: parent.width - 200
                height: parent.height
                color: "transparent"

                // Close Button Top Right
                Rectangle {
                    width: 30
                    height: 30
                    radius: 0
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 14
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    z: 10

                    Text {
                        text: "✕"
                        color: Theme.dimForeground
                        anchors.centerIn: parent
                        font.pixelSize: 14
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
                        spacing: 20
                        width: parent.width

                        Text {
                            text: "Alternância de Motor Web"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Escolha qual motor processa as páginas. O Chromium roda nativo embutido e o Firefox/Zen roda integrado com perfil isolado."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Engine Option 1: Chromium
                        Rectangle {
                            width: parent.width
                            height: 68
                            radius: 0
                            color: bridge.currentEngine === "chromium" ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.02)
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

                                Text { text: "⚡"; font.pixelSize: 24; anchors.verticalCenter: parent.verticalCenter }

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
                            radius: 0
                            color: bridge.currentEngine === "firefox" ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.02)
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

                                Text { text: "🦊"; font.pixelSize: 24; anchors.verticalCenter: parent.verticalCenter }

                                Column {
                                    spacing: 3
                                    Text {
                                        text: "Firefox / Zen Browser (Gecko)"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Alterna páginas para a instância Gecko/Zen Browser com máxima privacidade."
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
                        spacing: 16
                        width: parent.width

                        Text {
                            text: "Motor de Pesquisa Padrão"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Selecione o motor utilizado ao digitar buscas no lançador superior."
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
                                height: 50
                                radius: 0
                                color: (card.config.search_engine || "google") === modelData.id ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.02)
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
                                        radius: 0
                                        border.color: Theme.accent
                                        border.width: 2
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 0
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
                    }
                }

                // Section 3: Sincronização & Conta Google
                Item {
                    id: paneSync
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "sync"

                    Column {
                        spacing: 18
                        width: parent.width

                        Text {
                            text: "Conta Google & Sincronização"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Suporte nativo a login na sua Conta Google nos serviços web (Gmail, YouTube, Drive) com persistência completa de sessão."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Google Account Quick Login Card
                        Rectangle {
                            width: parent.width
                            height: 72
                            radius: 0
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Theme.border
                            border.width: 1

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Text { text: "🔐"; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }

                                Column {
                                    spacing: 3
                                    Text {
                                        text: "Login na Conta Google"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Abra a página de login oficial do Google para gerenciar sua sessão."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }

                            Rectangle {
                                width: 110
                                height: 34
                                radius: 0
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.accent

                                Text {
                                    text: "Fazer Login"
                                    color: Theme.background
                                    font.pixelSize: Theme.fontBody
                                    font.bold: true
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        bridge.settingsVisible = false;
                                        bridge.currentUrl = "https://accounts.google.com";
                                    }
                                }
                            }
                        }

                        // Chrome Profile Sync
                        Rectangle {
                            width: parent.width
                            height: 72
                            radius: 0
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Theme.border
                            border.width: 1

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 14

                                Text { text: "🔄"; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }

                                Column {
                                    spacing: 3
                                    Text {
                                        text: "Sincronizar Dados do Chrome"
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontBody
                                        font.bold: true
                                    }
                                    Text {
                                        text: "Importa favoritos e histórico de navegação do seu perfil do Chrome."
                                        color: Theme.dimForeground
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }
                            }

                            Rectangle {
                                width: 110
                                height: 34
                                radius: 0
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.selection
                                border.color: Theme.accent
                                border.width: 1

                                Text {
                                    text: "Sincronizar"
                                    color: Theme.foreground
                                    font.pixelSize: Theme.fontBody
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

                // Section 4: Aparência & Tema
                Item {
                    id: paneAppearance
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "appearance"

                    Column {
                        spacing: 20
                        width: parent.width

                        Text {
                            text: "Aparência e Integração de Tema"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "O OmaBrowser segue automaticamente a paleta e tema do Omarchy (~/.local/state/omarchy/current/theme)."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: 12
                            Repeater {
                                model: [
                                    { name: "Fundo", color: Theme.background },
                                    { name: "Superfície", color: Theme.surface },
                                    { name: "Variante", color: Theme.surfaceVariant },
                                    { name: "Destaque", color: Theme.accent },
                                    { name: "Borda", color: Theme.border }
                                ]

                                Column {
                                    spacing: 6
                                    Rectangle {
                                        width: 50
                                        height: 35
                                        radius: 0
                                        color: modelData.color
                                        border.color: Theme.border
                                        border.width: 1
                                    }
                                    Text {
                                        text: modelData.name
                                        color: Theme.dimForeground
                                        font.pixelSize: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Section 5: Sobre
                Item {
                    id: paneAbout
                    anchors.fill: parent
                    anchors.margins: 28
                    visible: card.activeSection === "about"

                    Column {
                        spacing: 14
                        width: parent.width

                        Text {
                            text: "Sobre o OmaBrowser"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "Navegador ultrarrápido construído em Rust e Qt6 WebEngine com o design elegante do ecossistema Omarchy e inspirado no Flea."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            text: "• Versão: 0.1.0\n• Motor Primário: Qt6 WebEngine (Chromium Blink/V8)\n• Motor Secundário: Zen Browser / Firefox (Gecko)\n• Backend: Rust (Cargo) + C++ Bridge\n• Atalho Lançador: Tecla Espaço ou passar o mouse no topo"
                            color: Theme.foreground
                            font.pixelSize: 13
                            lineHeight: 1.4
                        }
                    }
                }
            }
        }
    }
}
