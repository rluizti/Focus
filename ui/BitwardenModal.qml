import QtQuick
import QtQuick.Controls

Item {
    id: root
    visible: false
    anchors.fill: parent
    z: 1100

    signal openUrlRequested(string url)

    property string errorText: ""
    property string successText: ""
    property string toastText: ""
    property bool isBusy: false
    property bool isSendingEmail: false
    property int emailCooldown: 0
    property var onUnlockedCallback: null
    property bool isSyncingVault: false
    property bool syncVaultSuccess: false

    readonly property int itemRadius: Theme.cornerRadius > 0 ? Math.max(2, Theme.cornerRadius - 2) : 0

    ListModel {
        id: vaultModel
    }

    Timer {
        id: toastTimer
        interval: 2500
        repeat: false
        onTriggered: root.toastText = ""
    }

    function showToast(msg) {
        toastText = msg;
        toastTimer.restart();
    }

    Timer {
        id: vaultSearchDebounce
        interval: 150
        repeat: false
        onTriggered: {
            if (bridge.bitwardenUnlocked) {
                loadVaultItems(vaultSearchInput ? vaultSearchInput.text.trim() : "");
            }
        }
    }

    Timer {
        id: vaultSyncTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.isSyncingVault = false;
            root.syncVaultSuccess = true;
            loadVaultItems(vaultSearchInput ? vaultSearchInput.text.trim() : "");
            showToast("✓ Cofre sincronizado com sucesso!");
            vaultSyncResetTimer.restart();
        }
    }

    Timer {
        id: vaultSyncResetTimer
        interval: 2500
        repeat: false
        onTriggered: root.syncVaultSuccess = false
    }

    function loadVaultItems(search) {
        vaultModel.clear();
        try {
            var raw = bridge.listAllBitwardenItems(search || "");
            var arr = JSON.parse(raw);
            if (arr && Array.isArray(arr)) {
                for (var i = 0; i < arr.length; i++) {
                    var it = arr[i];
                    vaultModel.append({
                        itemId: it.id || "",
                        name: it.name || "Sem Nome",
                        username: it.username || "",
                        password: it.password || "",
                        uri: it.uri || "",
                        showPass: false
                    });
                }
            }
        } catch(e) {
            console.log("[BitwardenModal] Erro ao carregar itens do cofre:", e);
        }
    }

    function openModal(callback) {
        onUnlockedCallback = callback || null;
        errorText = "";
        successText = "";
        toastText = "";
        passwordInput.text = "";
        codeInput.text = "";
        isBusy = false;
        isSendingEmail = false;

        visible = true;

        if (bridge.bitwardenUnlocked) {
            if (vaultSearchInput) vaultSearchInput.text = "";
            loadVaultItems("");
            if (vaultSearchInput) vaultSearchInput.forceActiveFocus();
            return;
        }

        // Auto-preencher e-mail se já conhecido pelo CLI ou conta Google
        var savedEmail = bridge.getBitwardenEmail();
        if (!savedEmail || savedEmail.length === 0) {
            try {
                var g = JSON.parse(bridge.googleAccountJson);
                if (g && g.email) savedEmail = g.email;
            } catch(e) {}
        }
        if (emailInput.text.trim().length === 0 && savedEmail && savedEmail.length > 0) {
            emailInput.text = savedEmail;
        }

        if (emailInput.text.trim().length === 0) {
            emailInput.forceActiveFocus();
        } else {
            passwordInput.forceActiveFocus();
        }
    }

    function closeModal() {
        visible = false;
        errorText = "";
        successText = "";
        toastText = "";
        passwordInput.text = "";
        codeInput.text = "";
        isBusy = false;
        isSendingEmail = false;
        bridge.cancelBitwardenLogin();
    }

    function sendEmailCode() {
        if (isBusy || isSendingEmail || emailCooldown > 0) return;
        errorText = "";
        successText = "";

        var em = emailInput.text.trim();
        if (em.length === 0) {
            errorText = "Digite seu e-mail do Bitwarden.";
            emailInput.forceActiveFocus();
            return;
        }

        var pass = passwordInput.text.trim();
        if (pass.length === 0) {
            errorText = "Digite sua Senha Mestra para solicitar o código.";
            passwordInput.forceActiveFocus();
            return;
        }

        isSendingEmail = true;
        sendEmailTimer.targetEmail = em;
        sendEmailTimer.targetPass = pass;
        sendEmailTimer.start();
    }

    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: true
        running: root.emailCooldown > 0
        onTriggered: {
            if (root.emailCooldown > 0) {
                root.emailCooldown--;
            }
        }
    }

    Timer {
        id: sendEmailTimer
        interval: 30
        repeat: false
        property string targetEmail: ""
        property string targetPass: ""

        onTriggered: {
            var err = bridge.sendBitwardenEmailCode(targetEmail, targetPass);
            root.isSendingEmail = false;
            if (!err || err.length === 0) {
                root.errorText = "";
                root.successText = "Código enviado para " + targetEmail + "! Verifique sua caixa de entrada e insira o código abaixo.";
                root.emailCooldown = 60;
                codeInput.forceActiveFocus();
            } else {
                root.errorText = err;
                root.successText = "";
            }
        }
    }

    function submitAuth() {
        if (isBusy) return;
        errorText = "";
        successText = "";

        var pass = passwordInput.text.trim();
        if (pass.length === 0) {
            errorText = "Digite sua Senha Mestra.";
            passwordInput.forceActiveFocus();
            return;
        }

        var email = emailInput.text.trim();
        if (bridge.bitwardenCliStatus === "unauthenticated" && email.length === 0) {
            errorText = "Digite seu e-mail do Bitwarden.";
            emailInput.forceActiveFocus();
            return;
        }

        isBusy = true;
        authTimer.loginEmail = email;
        authTimer.loginPass = pass;
        authTimer.loginCode = codeInput.text.trim();
        authTimer.start();
    }

    Timer {
        id: authTimer
        interval: 50
        repeat: false
        property string loginEmail: ""
        property string loginPass: ""
        property string loginCode: ""

        onTriggered: {
            var err = "";
            var cliStatus = bridge.bitwardenCliStatus;

            if (loginCode.length > 0 || cliStatus === "unauthenticated") {
                err = bridge.loginBitwarden(loginEmail, loginPass, loginCode);
            } else if (cliStatus === "locked") {
                err = bridge.unlockBitwarden(loginPass);
                if (err && err.length > 0 && loginEmail.length > 0) {
                    var loginErr = bridge.loginBitwarden(loginEmail, loginPass, loginCode);
                    if (!loginErr || loginErr.length === 0) {
                        err = "";
                    } else {
                        err = loginErr;
                    }
                }
            }

            root.isBusy = false;
            if (err && err.length > 0) {
                root.errorText = err;
                passwordInput.forceActiveFocus();
            } else {
                var cb = root.onUnlockedCallback;
                if (cb && typeof cb === "function") {
                    root.closeModal();
                    cb();
                } else {
                    root.loadVaultItems("");
                    if (vaultSearchInput) vaultSearchInput.text = "";
                }
            }
        }
    }

    Connections {
        target: bridge
        function onBitwardenStatusChanged() {
            if (root.visible && bridge.bitwardenUnlocked) {
                root.loadVaultItems(vaultSearchInput ? vaultSearchInput.text.trim() : "");
            }
        }
    }

    // Fundo escurecido
    Rectangle {
        anchors.fill: parent
        color: "#aa000000"
        opacity: root.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Não fecha ao clicar fora por acidente
        }
    }

    // Card do Modal
    Rectangle {
        id: card
        width: bridge.bitwardenUnlocked ? Math.min(700, parent.width - 32) : Math.min(480, parent.width - 32)
        height: bridge.bitwardenUnlocked ? Math.min(580, parent.height - 40) : Math.min(authCol.implicitHeight + 44, parent.height - 40)
        anchors.centerIn: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        border.color: bridge.bitwardenUnlocked ? Theme.green : Theme.accent
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
        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // ==========================================
        // VISTA 1: COFRE DESBLOQUEADO (VAULT BROWSER)
        // ==========================================
        Item {
            id: vaultView
            anchors.fill: parent
            anchors.margins: 20
            visible: bridge.bitwardenUnlocked

            Column {
                anchors.fill: parent
                spacing: 14

                // Top Header do Cofre
                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: 38
                        height: 38
                        radius: root.itemRadius
                        color: Qt.rgba(0.2, 0.8, 0.4, 0.15)
                        border.color: Theme.green
                        border.width: 1

                        Glyph {
                            name: "shield"
                            size: 20
                            color: Theme.green
                            anchors.centerIn: parent
                        }
                    }

                    Column {
                        width: parent.width - 38 - 12 - vaultHeaderActions.width - 12
                        spacing: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            spacing: 8
                            Text {
                                text: "Cofre Bitwarden"
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.foreground
                            }
                            Rectangle {
                                height: 18
                                width: statusTxt.implicitWidth + 10
                                radius: 4
                                color: Qt.rgba(0.2, 0.8, 0.4, 0.15)
                                border.color: Theme.green
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: statusTxt
                                    text: "✓ Desbloqueado"
                                    color: Theme.green
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: Theme.fontFamily
                                    anchors.centerIn: parent
                                }
                            }
                        }

                        Text {
                            text: {
                                var em = bridge.getBitwardenEmail();
                                return (em && em.length > 0) ? em : "Sessão interna ativa no Focus";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.dimForeground
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Ações do Topo: Sincronizar, Bloquear, Fechar
                    Row {
                        id: vaultHeaderActions
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Botão Sincronizar
                        Rectangle {
                            height: 28
                            width: root.isSyncingVault ? 115 : (root.syncVaultSuccess ? 115 : 95)
                            radius: root.itemRadius
                            color: root.isSyncingVault ? Qt.rgba(1, 1, 1, 0.04) : (syncHover.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Qt.rgba(1, 1, 1, 0.05))
                            border.color: root.syncVaultSuccess ? Theme.green : Theme.border
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Glyph {
                                    name: "download"
                                    size: 12
                                    color: root.syncVaultSuccess ? Theme.green : Theme.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.isSyncingVault ? "Sincronizando..." : (root.syncVaultSuccess ? "✓ Sincronizado!" : "Sincronizar")
                                    color: root.syncVaultSuccess ? Theme.green : Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: syncHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isSyncingVault) return;
                                    root.isSyncingVault = true;
                                    bridge.syncBitwardenVault();
                                    vaultSyncTimer.restart();
                                }
                            }
                        }

                        // Botão Bloquear Cofre
                        Rectangle {
                            height: 28
                            width: 82
                            radius: root.itemRadius
                            color: lockHover.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : Qt.rgba(1, 0, 0, 0.08)
                            border.color: Theme.red
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Glyph {
                                    name: "lock"
                                    size: 11
                                    color: Theme.red
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Bloquear"
                                    color: Theme.red
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: lockHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    bridge.lockBitwarden();
                                }
                            }
                        }

                        // Botão Fechar Modal
                        Rectangle {
                            width: 28
                            height: 28
                            radius: root.itemRadius
                            color: closeVaultHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                            Text {
                                text: "✕"
                                color: Theme.dimForeground
                                font.pixelSize: 13
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: closeVaultHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeModal()
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                // Campo de Busca no Cofre
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: root.itemRadius
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.color: vaultSearchInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Glyph {
                            name: "search"
                            size: 14
                            color: Theme.dimForeground
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - 22 - (vaultSearchInput.text.length > 0 ? 24 : 0)
                            height: parent.height

                            Text {
                                text: "Pesquisar no cofre (nome, usuário, site)..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.25)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: vaultSearchInput.text.length === 0
                            }

                            TextInput {
                                id: vaultSearchInput
                                anchors.fill: parent
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: Theme.foreground
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.background
                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: vaultSearchDebounce.restart()
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 4
                            color: clearSearchHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            visible: vaultSearchInput.text.length > 0
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "✕"
                                color: Theme.dimForeground
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: clearSearchHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    vaultSearchInput.text = "";
                                    root.loadVaultItems("");
                                }
                            }
                        }
                    }
                }

                // Lista de Itens do Cofre
                ListView {
                    id: vaultListView
                    width: parent.width
                    height: parent.height - 120
                    clip: true
                    model: vaultModel
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        id: itemCard
                        width: vaultListView.width - 8
                        height: 60
                        radius: root.itemRadius
                        color: itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                        border.color: itemMouse.containsMouse ? Theme.accent : Theme.border
                        border.width: 1

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            // Ícone do Item
                            Rectangle {
                                width: 38
                                height: 38
                                radius: root.itemRadius
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                border.color: Theme.accent
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Glyph {
                                    name: "shield"
                                    size: 16
                                    color: Theme.accent
                                    anchors.centerIn: parent
                                }
                            }

                            // Dados do Item: Nome, Usuário e Prévia de Senha
                            Column {
                                width: parent.width - 38 - 12 - actionsRow.width - 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: model.name
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 8
                                    width: parent.width

                                    Text {
                                        text: model.username.length > 0 ? model.username : "Sem usuário"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.dimForeground
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        text: "•"
                                        font.pixelSize: 11
                                        color: Theme.border
                                        visible: model.password.length > 0
                                    }

                                    Row {
                                        spacing: 4
                                        visible: model.password.length > 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            text: model.showPass ? model.password : "••••••••••••"
                                            font.family: "Monospace"
                                            font.pixelSize: 10
                                            color: model.showPass ? Theme.accent : Theme.dimForeground
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 3
                                            color: eyeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: model.showPass ? "👁" : "🔒"
                                                font.pixelSize: 10
                                                anchors.centerIn: parent
                                            }

                                            MouseArea {
                                                id: eyeHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: model.showPass = !model.showPass
                                            }
                                        }
                                    }
                                }
                            }

                            // Botões de Ação à Direita: Copiar Usuário, Copiar Senha, Abrir
                            Row {
                                id: actionsRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // Copiar Usuário
                                Rectangle {
                                    height: 26
                                    width: 78
                                    radius: root.itemRadius
                                    color: copyUserHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Theme.border
                                    border.width: 1
                                    visible: model.username.length > 0

                                    Text {
                                        text: "Usuário"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: copyUserHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            bridge.copyToClipboard(model.username);
                                            root.showToast("✓ Usuário '" + model.username + "' copiado!");
                                        }
                                    }
                                }

                                // Copiar Senha
                                Rectangle {
                                    height: 26
                                    width: 74
                                    radius: root.itemRadius
                                    color: copyPassHover.containsMouse ? Qt.darker(Theme.accent, 1.1) : Theme.accent
                                    visible: model.password.length > 0

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Glyph {
                                            name: "lock"
                                            size: 10
                                            color: Theme.background
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Senha"
                                            color: Theme.background
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: copyPassHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            bridge.copyToClipboard(model.password);
                                            root.showToast("✓ Senha copiada!");
                                        }
                                    }
                                }

                                // Abrir Link
                                Rectangle {
                                    height: 26
                                    width: 28
                                    radius: root.itemRadius
                                    color: openUriHover.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Theme.border
                                    border.width: 1
                                    visible: model.uri.length > 0

                                    Glyph {
                                        name: "globe"
                                        size: 13
                                        color: Theme.foreground
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: openUriHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.openUrlRequested(model.uri);
                                            root.closeModal();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Estado Vazio do Cofre
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: vaultModel.count === 0 && !root.isBusy

                Glyph {
                    name: "shield"
                    size: 36
                    color: Theme.dimForeground
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: vaultSearchInput.text.trim().length > 0
                          ? ("Nenhum resultado para '" + vaultSearchInput.text + "'")
                          : "Nenhuma credencial encontrada no cofre."
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.dimForeground
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Toast Notificação Flutuante
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                height: 30
                width: toastTxt.implicitWidth + 24
                radius: 15
                color: Theme.green
                visible: root.toastText.length > 0
                opacity: root.toastText.length > 0 ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Text {
                    id: toastTxt
                    text: root.toastText
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
        }

        // ==========================================
        // VISTA 2: DESBLOQUEIO / LOGIN (AUTH FLOW)
        // ==========================================
        Column {
            id: authCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 14
            visible: !bridge.bitwardenUnlocked

            // Cabeçalho
            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 38
                    height: 38
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
                    width: parent.width - 80
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Bitwarden"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.foreground
                    }

                    Text {
                        text: bridge.bitwardenCliStatus === "locked"
                              ? "Cofre bloqueado. Digite sua Senha Mestra para desbloquear."
                              : "Faça login com seu e-mail e senha para sincronizar suas senhas."
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.dimForeground
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }

                // Botão Fechar Modal
                Rectangle {
                    width: 26
                    height: 26
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

            // Área de Entrada de Dados (E-mail + Senha Mestra + Código de Verificação)
            Column {
                width: parent.width
                spacing: 10

                // Campo de E-mail (exibido quando não logado no CLI)
                Column {
                    width: parent.width
                    spacing: 4
                    visible: bridge.bitwardenCliStatus === "unauthenticated"

                    Text {
                        text: "E-mail da Conta"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.dimForeground
                    }

                    Rectangle {
                        width: parent.width
                        height: 34
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

                // Campo de Senha Mestra
                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Senha Mestra (Master Password)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.dimForeground
                    }

                    Rectangle {
                        width: parent.width
                        height: 34
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
                            Keys.onReturnPressed: {
                                if (bridge.bitwardenCliStatus === "unauthenticated" && codeInput.text.trim().length === 0) {
                                    root.sendEmailCode();
                                } else {
                                    root.submitAuth();
                                }
                            }
                        }

                        Rectangle {
                            id: showPassBtn
                            property bool showPass: false
                            width: 26
                            height: 26
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

                // Botão "Enviar código para o meu e-mail"
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: root.itemRadius
                    visible: bridge.bitwardenCliStatus === "unauthenticated"
                    color: (root.emailCooldown > 0 || root.isSendingEmail)
                           ? Qt.rgba(1, 1, 1, 0.04)
                           : (sendEmailHover.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08))
                    border.color: (root.emailCooldown > 0 || root.isSendingEmail) ? Theme.border : Theme.accent
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Glyph {
                            name: "download"
                            size: 13
                            color: (root.emailCooldown > 0 || root.isSendingEmail) ? Theme.dimForeground : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.isSendingEmail
                                  ? "Enviando código por e-mail..."
                                  : (root.emailCooldown > 0
                                     ? ("Reenviar código em " + root.emailCooldown + "s")
                                     : "Enviar código para o meu e-mail")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: (root.emailCooldown > 0 || root.isSendingEmail) ? Theme.dimForeground : Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: sendEmailHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.emailCooldown > 0 || root.isSendingEmail) ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: root.sendEmailCode()
                    }
                }

                // Banner de Confirmação de Envio (Verde)
                Rectangle {
                    width: parent.width
                    implicitHeight: successTextCol.implicitHeight + 14
                    radius: root.itemRadius
                    color: Qt.rgba(0.2, 0.8, 0.4, 0.12)
                    border.color: Theme.green
                    border.width: 1
                    visible: root.successText.length > 0

                    Row {
                        id: successTextCol
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8

                        Text {
                            text: "✓"
                            color: Theme.green
                            font.bold: true
                            font.pixelSize: 13
                        }

                        Text {
                            text: root.successText
                            color: Theme.green
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width - 28
                        }
                    }
                }

                // Campo Código de Verificação (exibido apenas se ainda não autenticado no CLI)
                Column {
                    width: parent.width
                    spacing: 4
                    visible: bridge.bitwardenCliStatus === "unauthenticated"

                    Row {
                        spacing: 6
                        Text {
                            text: "Código de Verificação recebido no e-mail"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.dimForeground
                        }
                        Text {
                            text: "(6 dígitos)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.accent
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: root.itemRadius
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: codeInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1

                        TextInput {
                            id: codeInput
                            anchors.fill: parent
                            anchors.margins: 8
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.foreground
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.background
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            Keys.onReturnPressed: root.submitAuth()
                        }
                    }
                }

                // Mensagem de Erro
                Rectangle {
                    width: parent.width
                    implicitHeight: errorTextCol.implicitHeight + 14
                    radius: root.itemRadius
                    color: Qt.rgba(0.8, 0.2, 0.2, 0.12)
                    border.color: Theme.red
                    border.width: 1
                    visible: root.errorText.length > 0

                    Row {
                        id: errorTextCol
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8

                        Text {
                            text: "⚠"
                            color: Theme.red
                            font.bold: true
                            font.pixelSize: 13
                        }

                        Text {
                            text: root.errorText
                            color: Theme.red
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width - 28
                        }
                    }
                }
            }

            // Botões de Ação Inferiores
            Row {
                anchors.right: parent.right
                spacing: 10

                // Cancelar
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

                // Desbloquear / Confirmar e Entrar
                Rectangle {
                    width: (bridge.bitwardenCliStatus === "locked") ? 130 : 160
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
                            text: root.isBusy
                                  ? "Conectando..."
                                  : ((bridge.bitwardenCliStatus === "locked") ? "Acessar Cofre" : "Confirmar e Entrar")
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
