import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.fill: parent
    visible: menuCard.opacity > 0
    z: 9999

    property var currentRequest: null
    property var targetWebView: null

    // Click outside to dismiss
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.dismiss()
    }

    Rectangle {
        id: menuCard
        width: 230
        height: menuColumn.height + 12
        radius: Theme.cornerRadius
        color: Theme.surface
        border.color: Theme.activeBorder
        border.width: Theme.borderSize
        clip: true
        opacity: 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        // Swallowing clicks inside menu
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        Column {
            id: menuColumn
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 6
            spacing: 2

            // Navigation Row: Voltar, Avançar, Recarregar
            Row {
                width: parent.width - 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                // Voltar
                Rectangle {
                    width: (parent.width - 8) / 3
                    height: 28
                    radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                    color: backMouse.containsMouse ? Theme.selection : "transparent"
                    border.color: backMouse.containsMouse ? Theme.accent : "transparent"
                    border.width: 1

                    Glyph {
                        name: "arrow-left"
                        size: 13
                        color: (root.targetWebView && root.targetWebView.canGoBack) ? Theme.foreground : Theme.dimForeground
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.targetWebView) root.targetWebView.goBack();
                            root.dismiss();
                        }
                    }
                }

                // Avançar
                Rectangle {
                    width: (parent.width - 8) / 3
                    height: 28
                    radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                    color: fwdMouse.containsMouse ? Theme.selection : "transparent"
                    border.color: fwdMouse.containsMouse ? Theme.accent : "transparent"
                    border.width: 1

                    Glyph {
                        name: "arrow-right"
                        size: 13
                        color: (root.targetWebView && root.targetWebView.canGoForward) ? Theme.foreground : Theme.dimForeground
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: fwdMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.targetWebView) root.targetWebView.goForward();
                            root.dismiss();
                        }
                    }
                }

                // Recarregar
                Rectangle {
                    width: (parent.width - 8) / 3
                    height: 28
                    radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                    color: reloadMouse.containsMouse ? Theme.selection : "transparent"
                    border.color: reloadMouse.containsMouse ? Theme.accent : "transparent"
                    border.width: 1

                    Glyph {
                        name: "refresh"
                        size: 13
                        color: Theme.foreground
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: reloadMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.targetWebView) root.targetWebView.reload();
                            root.dismiss();
                        }
                    }
                }
            }

            // Separador
            Rectangle {
                width: parent.width - 16
                height: 1
                color: Theme.border
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Link Actions (se clicou em um link)
            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: openLinkMouse.containsMouse ? Theme.selection : "transparent"
                border.color: openLinkMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1
                visible: root.currentRequest && root.currentRequest.linkUrl && root.currentRequest.linkUrl.toString().length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "tabs"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Abrir Link em Nova Aba"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: openLinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentRequest && root.currentRequest.linkUrl) {
                            launcher.newTabRequested(root.currentRequest.linkUrl.toString(), root.currentWorkspace || "Principal");
                        }
                        root.dismiss();
                    }
                }
            }

            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: copyLinkMouse.containsMouse ? Theme.selection : "transparent"
                border.color: copyLinkMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1
                visible: root.currentRequest && root.currentRequest.linkUrl && root.currentRequest.linkUrl.toString().length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "copy"; size: 12; color: Theme.dimForeground; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Copiar Link"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: copyLinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentRequest && root.currentRequest.linkUrl) {
                            if (root.targetWebView) root.targetWebView.triggerWebPageAction(WebEngineView.CopyLinkToClipboard);
                        }
                        root.dismiss();
                    }
                }
            }

            // Selection Actions (se há texto selecionado)
            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: copyTextMouse.containsMouse ? Theme.selection : "transparent"
                border.color: copyTextMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1
                visible: root.currentRequest && root.currentRequest.selectedText && root.currentRequest.selectedText.length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "copy"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Copiar"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: copyTextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.targetWebView) root.targetWebView.triggerWebPageAction(WebEngineView.Copy);
                        root.dismiss();
                    }
                }
            }

            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: searchTextMouse.containsMouse ? Theme.selection : "transparent"
                border.color: searchTextMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1
                visible: root.currentRequest && root.currentRequest.selectedText && root.currentRequest.selectedText.length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "search"; size: 12; color: Theme.dimForeground; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Pesquisar no Google"
                        color: Theme.foreground
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: searchTextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentRequest && root.currentRequest.selectedText) {
                            var query = root.currentRequest.selectedText.trim();
                            launcher.openUrlInTab("https://www.google.com/search?q=" + encodeURIComponent(query));
                        }
                        root.dismiss();
                    }
                }
            }

            // Editable actions: Colar / Recortar
            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: pasteMouse.containsMouse ? Theme.selection : "transparent"
                border.color: pasteMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1
                visible: root.currentRequest && root.currentRequest.isContentEditable

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "clipboard"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Colar"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: pasteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.targetWebView) root.targetWebView.triggerWebPageAction(WebEngineView.Paste);
                        root.dismiss();
                    }
                }
            }

            // Separador se tiver link ou seleção
            Rectangle {
                width: parent.width - 16
                height: 1
                color: Theme.border
                anchors.horizontalCenter: parent.horizontalCenter
                visible: (root.currentRequest && root.currentRequest.linkUrl && root.currentRequest.linkUrl.toString().length > 0) ||
                         (root.currentRequest && root.currentRequest.selectedText && root.currentRequest.selectedText.length > 0)
            }

            // Inspecionar Elemento (F12)
            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: inspectMouse.containsMouse ? Theme.selection : "transparent"
                border.color: inspectMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "sliders"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Inspecionar Elemento (F12)"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: inspectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.devToolsOpen = true;
                        root.dismiss();
                    }
                }
            }

            // Configurações
            Rectangle {
                width: parent.width - 12
                height: 28
                radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0
                anchors.horizontalCenter: parent.horizontalCenter
                color: settingsMouse.containsMouse ? Theme.selection : "transparent"
                border.color: settingsMouse.containsMouse ? Theme.accent : "transparent"
                border.width: 1

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Glyph { name: "settings"; size: 12; color: Theme.dimForeground; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Configurações"; color: Theme.foreground; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bridge.settingsVisible = true;
                        root.dismiss();
                    }
                }
            }
        }
    }

    function showAt(request, webView, globalPos) {
        currentRequest = request;
        targetWebView = webView;

        // Position menu inside window bounds
        var px = globalPos.x;
        var py = globalPos.y;

        if (px + menuCard.width > root.width - 12) {
            px = root.width - menuCard.width - 12;
        }
        if (py + menuCard.height > root.height - 12) {
            py = root.height - menuCard.height - 12;
        }

        menuCard.x = Math.max(10, px);
        menuCard.y = Math.max(10, py);
        menuCard.opacity = 1;
    }

    function dismiss() {
        menuCard.opacity = 0;
        currentRequest = null;
        targetWebView = null;
    }
}
