import QtQuick

Item {
    id: root
    width: 320
    height: 160
    anchors.top: parent.top
    anchors.topMargin: 16
    anchors.right: parent.right
    anchors.rightMargin: 20
    z: 1050
    visible: false

    property string saveUrl: ""
    property string saveDomain: ""
    property string saveUsername: ""
    property string savePassword: ""
    property bool isSaved: false

    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    function promptSave(url, username, password) {
        if (!url || !username || !password) return;
        saveUrl = url;
        saveUsername = username;
        savePassword = password;
        isSaved = false;

        var d = url;
        var m = url.match(/:\/\/(www\.)?([^\/]+)/);
        if (m && m[2]) {
            d = m[2];
        }
        saveDomain = d;
        visible = true;
        autoDismissTimer.restart();
    }

    function dismiss() {
        visible = false;
        autoDismissTimer.stop();
    }

    Timer {
        id: autoDismissTimer
        interval: 15000 // 15 seconds like Chrome
        repeat: false
        onTriggered: root.dismiss()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: Theme.accent
        border.width: 1

        scale: root.visible ? 1.0 : 0.9
        opacity: root.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Top row: Header
            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: root.itemRadius
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    border.color: Theme.accent
                    border.width: 1

                    Glyph {
                        name: "shield"
                        size: 14
                        color: Theme.accent
                        anchors.centerIn: parent
                    }
                }

                Column {
                    width: parent.width - 66
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.isSaved ? "Senha salva!" : "Salvar senha?"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.isSaved ? Theme.green : Theme.foreground
                    }

                    Text {
                        text: root.saveDomain + " • Bitwarden"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.dimForeground
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: root.itemRadius
                    color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    Text {
                        text: "✕"
                        color: Theme.dimForeground
                        font.pixelSize: 10
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Credential info
            Column {
                width: parent.width
                spacing: 3

                Row {
                    spacing: 6
                    width: parent.width

                    Text {
                        text: "Usuário:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.dimForeground
                    }

                    Text {
                        text: root.saveUsername
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.foreground
                        elide: Text.ElideRight
                        width: parent.width - 60
                    }
                }

                Row {
                    spacing: 6
                    width: parent.width

                    Text {
                        text: "Senha:"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.dimForeground
                    }

                    Text {
                        text: "••••••••••••"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.foreground
                    }
                }
            }

            // Buttons Row
            Row {
                anchors.right: parent.right
                spacing: 8
                visible: !root.isSaved

                Rectangle {
                    width: 75
                    height: 26
                    radius: root.itemRadius
                    color: neverMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        text: "Agora não"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.dimForeground
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: neverMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismiss()
                    }
                }

                Rectangle {
                    width: 75
                    height: 26
                    radius: root.itemRadius
                    color: saveMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent

                    Text {
                        text: "Salvar"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.background
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bridge.saveBitwardenCredential(root.saveUrl, root.saveUsername, root.savePassword);
                            root.isSaved = true;
                            dismissAfterSavedTimer.start();
                        }
                    }
                }
            }

            // Saved confirmation state
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                visible: root.isSaved

                Text {
                    text: "✓ Integrado ao cofre do Bitwarden"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.green
                }
            }
        }
    }

    Timer {
        id: dismissAfterSavedTimer
        interval: 1400
        repeat: false
        onTriggered: root.dismiss()
    }
}
