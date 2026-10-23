import QtQuick
import QtQuick.Controls

Item {
    id: root
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: visible ? 16 : -100
    width: Math.min(540, parent.width - 32)
    height: 72
    z: 9999
    visible: opacity > 0
    opacity: 0.0

    Behavior on anchors.topMargin {
        NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }
    Behavior on opacity {
        NumberAnimation { duration: 200 }
    }

    property bool isSuccess: false

    function open() {
        isSuccess = false;
        root.opacity = 1.0;
        root.anchors.topMargin = 16;
    }

    function close() {
        root.opacity = 0.0;
        root.anchors.topMargin = -100;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.cornerRadius > 0 ? Theme.cornerRadius : 8
        border.color: root.isSuccess ? Theme.green : Theme.activeBorder
        border.width: 1
        clip: true

        Rectangle {
            anchors.fill: parent
            color: root.isSuccess ? Qt.rgba(0.2, 0.8, 0.4, 0.08) : Qt.rgba(1, 1, 1, 0.03)
        }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: root.isSuccess ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                border.color: root.isSuccess ? Theme.green : Theme.accent
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Glyph {
                    name: root.isSuccess ? "check" : "globe"
                    size: 20
                    color: root.isSuccess ? Theme.green : Theme.accent
                    anchors.centerIn: parent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                width: parent.width - 40 - 14 - buttonsRow.width - 14

                Text {
                    text: root.isSuccess ? "Focus é o navegador padrão!" : "Definir Focus como navegador padrão?"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    text: root.isSuccess ? "Links externos e documentos abrirão no Focus." : "Abra links da web e documentos diretamente no Focus."
                    color: Theme.dimForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Row {
                id: buttonsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: !root.isSuccess

                // Botão "Agora não"
                Rectangle {
                    width: 76
                    height: 30
                    radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 4
                    color: notNowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        text: "Agora não"
                        color: Theme.dimForeground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: notNowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cfg = {};
                            try { cfg = JSON.parse(bridge.configJson); } catch(e) {}
                            cfg.asked_default_browser = true;
                            bridge.saveConfig(JSON.stringify(cfg));
                            root.close();
                        }
                    }
                }

                // Botão "Definir como padrão"
                Rectangle {
                    width: 125
                    height: 30
                    radius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 4
                    color: setDefaultMouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                    border.color: Theme.accent
                    border.width: 1

                    Text {
                        text: "Definir como padrão"
                        color: Theme.background
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: setDefaultMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bridge.setAsDefaultBrowser();
                            var cfg = {};
                            try { cfg = JSON.parse(bridge.configJson); } catch(e) {}
                            cfg.asked_default_browser = true;
                            bridge.saveConfig(JSON.stringify(cfg));
                            root.isSuccess = true;
                            autoCloseTimer.restart();
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 1800
        onTriggered: root.close()
    }
}
