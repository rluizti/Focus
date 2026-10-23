import QtQuick

Rectangle {
    id: root
    width: parent ? parent.width : 400
    height: 32
    color: Theme.surface
    z: 10

    property string inspectedTitle: ""
    property string inspectedUrl: ""
    property string currentDockSide: "window"
    signal dockSideRequested(string side)
    signal closeRequested()

    Rectangle {
        width: parent.width
        height: 1
        anchors.bottom: parent.bottom
        color: Theme.border
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        width: parent.width - 240

        Rectangle {
            width: 20
            height: 20
            radius: 4
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            anchors.verticalCenter: parent.verticalCenter

            Glyph {
                name: "terminal"
                size: 11
                color: Theme.accent
                anchors.centerIn: parent
            }
        }

        Text {
            text: "DevTools"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "•"
            color: Theme.dimForeground
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: textTitle.text.length > 0
        }

        Text {
            id: textTitle
            text: root.inspectedTitle.length > 0 ? root.inspectedTitle : root.inspectedUrl
            color: Theme.dimForeground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
            width: Math.min(contentWidth, root.width - 320)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Right Controls: Dock selector & Close
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Label
        Text {
            text: "Disposição:"
            color: Theme.dimForeground
            font.family: Theme.fontFamily
            font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        // Segmented Dock Selector
        Rectangle {
            height: 24
            width: 4 * 26 + 6
            radius: 4
            color: Theme.surfaceVariant
            border.color: Theme.border
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Row {
                anchors.centerIn: parent
                spacing: 2

                // 1. Separate Window (Undock)
                Rectangle {
                    width: 24
                    height: 20
                    radius: 3
                    color: root.currentDockSide === "window" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (undockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: root.currentDockSide === "window" ? Theme.accent : "transparent"
                    border.width: 1

                    // Undock vector icon
                    Item {
                        width: 14
                        height: 12
                        anchors.centerIn: parent

                        // Back window
                        Rectangle {
                            width: 9
                            height: 8
                            anchors.top: parent.top
                            anchors.right: parent.right
                            color: "transparent"
                            border.color: root.currentDockSide === "window" ? Theme.accent : Theme.dimForeground
                            border.width: 1
                        }

                        // Front window
                        Rectangle {
                            width: 9
                            height: 8
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            color: root.currentDockSide === "window" ? Theme.surface : Theme.surfaceVariant
                            border.color: root.currentDockSide === "window" ? Theme.accent : Theme.foreground
                            border.width: 1
                        }
                    }

                    MouseArea {
                        id: undockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dockSideRequested("window")
                    }
                }

                // 2. Dock Left
                Rectangle {
                    width: 24
                    height: 20
                    radius: 3
                    color: root.currentDockSide === "left" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (dockLeftMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: root.currentDockSide === "left" ? Theme.accent : "transparent"
                    border.width: 1

                    // Dock Left vector icon
                    Rectangle {
                        width: 14
                        height: 11
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.currentDockSide === "left" ? Theme.accent : Theme.dimForeground
                        border.width: 1

                        Rectangle {
                            width: 4
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            color: root.currentDockSide === "left" ? Theme.accent : Theme.dimForeground
                        }
                    }

                    MouseArea {
                        id: dockLeftMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dockSideRequested("left")
                    }
                }

                // 3. Dock Bottom
                Rectangle {
                    width: 24
                    height: 20
                    radius: 3
                    color: root.currentDockSide === "bottom" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (dockBottomMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: root.currentDockSide === "bottom" ? Theme.accent : "transparent"
                    border.width: 1

                    // Dock Bottom vector icon
                    Rectangle {
                        width: 14
                        height: 11
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.currentDockSide === "bottom" ? Theme.accent : Theme.dimForeground
                        border.width: 1

                        Rectangle {
                            height: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: root.currentDockSide === "bottom" ? Theme.accent : Theme.dimForeground
                        }
                    }

                    MouseArea {
                        id: dockBottomMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dockSideRequested("bottom")
                    }
                }

                // 4. Dock Right
                Rectangle {
                    width: 24
                    height: 20
                    radius: 3
                    color: root.currentDockSide === "right" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : (dockRightMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: root.currentDockSide === "right" ? Theme.accent : "transparent"
                    border.width: 1

                    // Dock Right vector icon
                    Rectangle {
                        width: 14
                        height: 11
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.currentDockSide === "right" ? Theme.accent : Theme.dimForeground
                        border.width: 1

                        Rectangle {
                            width: 4
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            color: root.currentDockSide === "right" ? Theme.accent : Theme.dimForeground
                        }
                    }

                    MouseArea {
                        id: dockRightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dockSideRequested("right")
                    }
                }
            }
        }

        // Divider
        Rectangle {
            width: 1
            height: 16
            color: Theme.border
            anchors.verticalCenter: parent.verticalCenter
        }

        // Close button
        Rectangle {
            width: 22
            height: 22
            radius: 4
            color: dtCloseMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.2) : "transparent"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "✕"
                color: dtCloseMouse.containsMouse ? Theme.red : Theme.dimForeground
                font.pixelSize: 10
                anchors.centerIn: parent
            }

            MouseArea {
                id: dtCloseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}
