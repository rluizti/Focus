import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 1100

    property string errorText: ""
    property bool isBusy: false
    property string authMode: "locked" // "locked" or "unauthenticated"
    property var onUnlockedCallback: null

    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    function openModal(callback) {
        onUnlockedCallback = callback || null;
        errorText = "";
        passwordInput.text = "";
        isBusy = false;
        var status = bridge.bitwardenCliStatus;
        if (status === "unauthenticated") {
            authMode = "unauthenticated";
        } else {
            authMode = "locked";
        }
        visible = true;
        if (authMode === "unauthenticated" && emailInput.text.length === 0) {
            emailInput.forceActiveFocus();
        } else {
            passwordInput.forceActiveFocus();
        }
    }

    function closeModal() {
        visible = false;
        errorText = "";
        passwordInput.text = "";
        isBusy = false;
    }

    function submitAuth() {
        if (isBusy) return;
        errorText = "";

        var pass = passwordInput.text.trim();
        if (pass.length === 0) {
            errorText = "Digite sua senha mestra.";
            return;
        }

        isBusy = true;

        if (authMode === "unauthenticated") {
            var email = emailInput.text.trim();
            if (email.length === 0) {
                isBusy = false;
                errorText = "Digite seu e-mail do Bitwarden.";
                return;
            }
            // Execute login asynchronously via Timer so UI doesn't freeze
            authTimer.loginEmail = email;
            authTimer.loginPass = pass;
            authTimer.action = "login";
            authTimer.start();
        } else {
            authTimer.loginPass = pass;
            authTimer.action = "unlock";
            authTimer.start();
        }
    }

    Timer {
        id: authTimer
        interval: 50
        repeat: false
        property string action: "unlock"
        property string loginEmail: ""
        property string loginPass: ""

        onTriggered: {
            var err = "";
            if (action === "login") {
                err = bridge.loginBitwarden(loginEmail, loginPass);
            } else {
                err = bridge.unlockBitwarden(loginPass);
            }

            root.isBusy = false;
            if (err && err.length > 0) {
                root.errorText = err;
            } else {
                var cb = root.onUnlockedCallback;
                root.closeModal();
                if (cb && typeof cb === "function") {
                    cb();
                }
            }
        }
    }

    // Backdrop
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

    // Modal Card
    Rectangle {
        id: card
        width: Math.min(480, parent.width - 32)
        height: root.authMode === "unauthenticated" ? 380 : 310
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

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: root.itemRadius
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                    border.color: Theme.accent
                    border.width: 1

                    Glyph {
                        name: "shield"
                        size: 20
                        color: Theme.accent
                        anchors.centerIn: parent
                    }
                }

                Column {
                    width: parent.width - 90
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.authMode === "unauthenticated" ? "Conectar ao Bitwarden" : "Desbloquear Bitwarden"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        text: root.authMode === "unauthenticated"
                            ? "Entre com sua conta Bitwarden para integrar suas senhas."
                            : "Digite sua Senha Mestra para integrar e preencher credenciais."
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.dimForeground
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }

                // Close Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: root.itemRadius
                    color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    Text {
                        text: "✕"
                        color: Theme.dimForeground
                        font.pixelSize: 12
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Inputs Area
            Column {
                width: parent.width
                spacing: 12

                // Email Input (only if unauthenticated)
                Column {
                    width: parent.width
                    spacing: 5
                    visible: root.authMode === "unauthenticated"

                    Text {
                        text: "E-mail do Bitwarden"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.dimForeground
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.itemRadius
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: emailInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1

                        TextInput {
                            id: emailInput
                            anchors.fill: parent
                            anchors.margins: 8
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.foreground
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.background
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: passwordInput.forceActiveFocus()
                        }
                    }
                }

                // Master Password Input
                Column {
                    width: parent.width
                    spacing: 5

                    Row {
                        width: parent.width
                        Text {
                            text: "Senha Mestra (Master Password)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.dimForeground
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: root.itemRadius
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: passwordInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1

                        TextInput {
                            id: passwordInput
                            anchors.left: parent.left
                            anchors.right: showPassBtn.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.foreground
                            echoMode: showPassBtn.showPass ? TextInput.Normal : TextInput.Password
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.background
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: root.submitAuth()
                        }

                        Rectangle {
                            id: showPassBtn
                            property bool showPass: false
                            width: 28
                            height: 28
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: showPassMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            radius: 4

                            Text {
                                text: showPassBtn.showPass ? "👁" : "🔒"
                                font.pixelSize: 11
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: showPassMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showPassBtn.showPass = !showPassBtn.showPass
                            }
                        }
                    }
                }

                // Error message
                Text {
                    text: root.errorText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.red
                    visible: root.errorText.length > 0
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // Bottom Buttons
            Row {
                anchors.right: parent.right
                spacing: 10

                // Cancel Button
                Rectangle {
                    width: 80
                    height: 32
                    radius: root.itemRadius
                    color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        text: "Cancelar"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.dimForeground
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeModal()
                    }
                }

                // Unlock / Login Submit Button
                Rectangle {
                    width: 120
                    height: 32
                    radius: root.itemRadius
                    color: root.isBusy ? Theme.border : (submitMouse.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent)

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Glyph {
                            name: "lock"
                            size: 12
                            color: Theme.background
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.isBusy
                        }

                        Text {
                            text: root.isBusy ? "Conectando..." : (root.authMode === "unauthenticated" ? "Entrar" : "Desbloquear")
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.background
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.isBusy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: root.submitAuth()
                    }
                }
            }
        }
    }
}
