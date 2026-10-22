import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: bridge.settingsVisible
    anchors.fill: parent
    z: 999

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
                            { id: "sync", label: "Conta & Sync", glyph: "lock" },
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
                            text: "Aparência & Integração Omarchy"
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            text: "O Focus adota em tempo real as cores, cantos arredondados e espessura de borda definidos pelo tema do seu sistema Omarchy."
                            color: Theme.dimForeground
                            font.pixelSize: Theme.fontBody
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        // Theme Info Card
                        Rectangle {
                            width: parent.width
                            height: 110
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
                                    Text { text: "Transparência Inativa:"; color: Theme.dimForeground; font.pixelSize: 12; width: 180 }
                                    Text { text: "0.88 quando desfocado, 1.0 com foco/cursor"; color: Theme.accent; font.bold: true; font.pixelSize: 12 }
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
