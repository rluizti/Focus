import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 1100

    signal openUrlRequested(string url)
    signal newTabRequested(string url)

    property string searchText: ""
    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    function openModal() {
        searchText = "";
        if (historySearchInput) historySearchInput.text = "";
        root.visible = true;
        filterHistory();
        if (historySearchInput) historySearchInput.forceActiveFocus();
    }

    function closeModal() {
        root.visible = false;
    }

    ListModel {
        id: historyModel
    }

    function filterHistory() {
        historyModel.clear();
        try {
            var raw = JSON.parse(bridge.historyJson || "[]");
            var q = searchText.trim().toLowerCase();
            var count = 0;
            for (var i = 0; i < raw.length && count < 250; i++) {
                var item = raw[i];
                if (!item || !item.url) continue;
                var title = item.title || "";
                var url = item.url || "";
                var domain = item.domain || "";
                if (q.length === 0 || title.toLowerCase().indexOf(q) !== -1 || url.toLowerCase().indexOf(q) !== -1 || domain.toLowerCase().indexOf(q) !== -1) {
                    historyModel.append({
                        title: title.length > 0 ? title : domain,
                        url: url,
                        domain: domain.length > 0 ? domain : "web"
                    });
                    count++;
                }
            }
        } catch(e) {}
    }

    Connections {
        target: bridge
        function onHistoryJsonChanged() {
            if (root.visible) {
                root.filterHistory();
            }
        }
    }

    // Fundo escurecido (clicar fora fecha)
    Rectangle {
        anchors.fill: parent
        color: "#aa000000"
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeModal()
        }
    }

    // Card Flutuante do Histórico
    Rectangle {
        id: card
        width: Math.min(680, parent.width - 32)
        height: Math.min(540, parent.height - 40)
        anchors.centerIn: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.accent
        border.width: 1
        clip: true

        scale: root.visible ? 1.0 : 0.95
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        // Impede cliques dentro do card de fecharem a janela
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Top Header: Ícone, Título, Contador e Botão Fechar
            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 30
                        height: 30
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Theme.border
                        border.width: 1

                        Glyph {
                            name: "history"
                            size: 15
                            color: Theme.accent
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Histórico de Navegação"
                            color: Theme.foreground
                            font.pixelSize: 15
                            font.bold: true
                            font.family: Theme.fontFamily
                        }

                        Text {
                            text: historyModel.count + " páginas registradas"
                            color: Theme.dimForeground
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }
                    }
                }

                // Ações da Direita: Sincronizar e Fechar
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Botão Sincronizar
                    Rectangle {
                        height: 26
                        width: 100
                        radius: root.itemRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Theme.border
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Glyph { name: "refresh"; size: 11; color: Theme.foreground; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Sincronizar"; color: Theme.foreground; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bridge.syncChrome();
                                root.filterHistory();
                            }
                        }
                    }

                    // Botão Fechar (X)
                    Rectangle {
                        width: 26
                        height: 26
                        radius: root.itemRadius
                        color: closeBtnMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: closeBtnMouse.containsMouse ? Theme.red : Theme.border
                        border.width: 1

                        Glyph {
                            name: "x"
                            size: 12
                            color: closeBtnMouse.containsMouse ? Theme.red : Theme.foreground
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: closeBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeModal()
                        }
                    }
                }
            }

            // Barra de Busca no Histórico
            Rectangle {
                width: parent.width
                height: 36
                radius: root.itemRadius
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: historySearchInput.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    Glyph {
                        name: "search"
                        size: 13
                        color: historySearchInput.activeFocus ? Theme.accent : Theme.dimForeground
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: historySearchInput
                        width: parent.width - 45
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        font.pixelSize: 12
                        font.family: Theme.fontFamily
                        selectByMouse: true
                        clip: true

                        Text {
                            text: "Filtrar por título, domínio ou URL..."
                            color: Theme.dimForeground
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            visible: !historySearchInput.text && !historySearchInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            root.searchText = text;
                            root.filterHistory();
                        }

                        Keys.onEscapePressed: root.closeModal()
                    }

                    // Botão Limpar Busca
                    Glyph {
                        name: "x"
                        size: 11
                        color: Theme.dimForeground
                        visible: historySearchInput.text.length > 0
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: historySearchInput.text = ""
                        }
                    }
                }
            }

            // Lista de Histórico
            Rectangle {
                width: parent.width
                height: card.height - 165
                radius: root.itemRadius
                color: Qt.rgba(0, 0, 0, 0.15)
                border.color: Theme.border
                border.width: 1
                clip: true

                ListView {
                    id: historyListView
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    model: historyModel
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        width: historyListView.width - 8
                        height: 48
                        radius: root.itemRadius
                        color: itemMouse.containsMouse ? Theme.selection : "transparent"
                        border.color: itemMouse.containsMouse ? Theme.accent : "transparent"
                        border.width: 1

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: function(mouse) {
                                root.closeModal();
                                if (mouse.button === Qt.MiddleButton) {
                                    root.newTabRequested(model.url);
                                } else {
                                    root.openUrlRequested(model.url);
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            // Badge do Domínio e Título
                            Row {
                                anchors.left: parent.left
                                anchors.right: hoverActionsRow.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                // Badge do Domínio
                                Rectangle {
                                    width: Math.min(110, Math.max(50, domainText.implicitWidth + 14))
                                    height: 22
                                    radius: root.itemRadius
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                    border.color: Theme.border
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: domainText
                                        text: model.domain
                                        color: Theme.accent
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                        anchors.centerIn: parent
                                    }
                                }

                                // Título e URL
                                Column {
                                    width: parent.width - 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: model.title
                                        color: Theme.foreground
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        width: parent.width
                                        text: model.url
                                        color: Theme.dimForeground
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            // Botões Rápidos no Hover
                            Row {
                                id: hoverActionsRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                visible: itemMouse.containsMouse
                                z: 5

                                // Abrir em Nova Aba
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: root.itemRadius
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Theme.border
                                    border.width: 1

                                    Glyph { name: "plus"; size: 10; color: Theme.foreground; anchors.centerIn: parent }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.closeModal();
                                            root.newTabRequested(model.url);
                                        }
                                    }
                                }

                                // Copiar Link
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: root.itemRadius
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Theme.border
                                    border.width: 1

                                    Glyph { name: "copy"; size: 10; color: Theme.foreground; anchors.centerIn: parent }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: bridge.copyToClipboard(model.url)
                                    }
                                }
                            }
                        }
                    }
                }

                // Estado Vazio
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: historyModel.count === 0

                    Glyph {
                        name: "history"
                        size: 32
                        color: Theme.dimForeground
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: historySearchInput.text.length > 0 ? "Nenhum resultado encontrado para o filtro." : "Nenhum histórico registrado no momento."
                        color: Theme.dimForeground
                        font.pixelSize: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Rodapé com atalho
            Row {
                width: parent.width
                Text {
                    text: "Dica: Clique com o botão esquerdo para abrir ou no meio para nova aba • Pressione Esc para fechar"
                    color: Theme.dimForeground
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (root.visible) root.closeModal();
        }
    }
}
