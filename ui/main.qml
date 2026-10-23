import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: window
    visible: true
    width: 1280
    height: 800
    minimumWidth: 600
    minimumHeight: 400
    title: activeWebTitle ? (activeWebTitle + " — Focus") : "Focus"
    color: Theme.background

    function mapAcceptLanguage(lang) {
        if (!lang) return "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7";
        if (lang === "pt-BR" || lang === "pt") {
            return "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "es-ES" || lang === "es") {
            return "es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "fr-FR" || lang === "fr") {
            return "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "de-DE" || lang === "de") {
            return "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "it-IT" || lang === "it") {
            return "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "ja-JP" || lang === "ja") {
            return "ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7";
        } else if (lang === "zh-CN" || lang === "zh") {
            return "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7";
        } else {
            return "en-US,en;q=0.9";
        }
    }

    property string currentAppLanguage: {
        try {
            var cfg = JSON.parse(bridge.configJson);
            return (cfg && cfg.language) ? cfg.language : "pt-BR";
        } catch(e) {
            return "pt-BR";
        }
    }

    function isExternalAuthHost(host) {
        var normalized = (host || "").toLowerCase();
        return normalized === "accounts.google.com"
            || normalized === "auth.openai.com"
            || normalized === "login.microsoftonline.com"
            || normalized === "appleid.apple.com";
    }

    function isExternalAuthRequest(url) {
        if (!url) return false;
        if (window.isExternalAuthHost(url.host)) return true;
        var route = (url.path || "").toLowerCase();
        var query = (url.query || "").toLowerCase();
        return /(oauth|authorize|signin|sign-in|login|sso)/.test(route)
            && /(client_id=|redirect_uri=|response_type=|samlrequest=)/.test(query);
    }

    property bool externalAuthNoticeVisible: false
    function handoffAuthentication(sourceUrl) {
        if (bridge.openExternalUrl(sourceUrl)) {
            externalAuthNoticeVisible = true;
            externalAuthNoticeTimer.restart();
        }
    }

    WebEngineProfile {
        id: persistentWebProfile
        storageName: "focus"
        offTheRecord: false
        persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        httpCacheType: WebEngineProfile.DiskHttpCache
        httpAcceptLanguage: window.mapAcceptLanguage(window.currentAppLanguage)
    }

    Connections {
        target: bridge
        function onConfigJsonChanged() {
            try {
                var cfg = JSON.parse(bridge.configJson);
                if (cfg && cfg.language && cfg.language !== window.currentAppLanguage) {
                    window.currentAppLanguage = cfg.language;
                    persistentWebProfile.httpAcceptLanguage = window.mapAcceptLanguage(cfg.language);
                }
            } catch(e) {}
        }
    }

    onActiveChanged: {
        if (active) requestUpdate();
    }
    onVisibilityChanged: function() {
        if (window.visibility !== Window.Hidden) {
            window.requestUpdate();
        }
    }
    onClosing: function(close) {
        window.saveCurrentSession();
    }
    function handleEscapeKey(): bool {
        if (bitwardenModal.visible) {
            bitwardenModal.closeModal();
        } else if (savePasswordPrompt.visible) {
            savePasswordPrompt.dismiss();
        } else if (contextMenu.visible) {
            contextMenu.dismiss();
        } else if (historyModal.visible) {
            historyModal.closeModal();
        } else if (window.devToolsOpen) {
            window.devToolsOpen = false;
        } else if (bridge.settingsVisible) {
            bridge.settingsVisible = false;
        } else if (bridge.launcherVisible) {
            if (launcher.isSiteConfigExpanded) {
                launcher.isSiteConfigExpanded = false;
            } else {
                launcher.isExpanded = false;
                bridge.launcherVisible = false;
            }
        } else if (window.splitViewActive) {
            window.splitViewActive = false;
        } else {
            return false;
        }
        return true;
    }
    Component.onCompleted: {
        window.restoreSession();
        checkFirstLaunchDefaultBrowserTimer.restart();
    }

    Timer {
        id: checkFirstLaunchDefaultBrowserTimer
        interval: 1200
        repeat: false
        onTriggered: {
            try {
                var cfg = JSON.parse(bridge.configJson || "{}");
                if (cfg.auto_sync_google === true) {
                    bridge.startAutoSync();
                }
                if (!bridge.isDefaultBrowser() && cfg.asked_default_browser !== true) {
                    defaultBrowserPrompt.open();
                }
            } catch(e) {}
        }
    }

    Timer {
        id: externalAuthNoticeTimer
        interval: 6000
        onTriggered: window.externalAuthNoticeVisible = false
    }

    property bool devToolsOpen: false
    property string devToolsDockSide: "window" // "window", "bottom", "right", "left"
    property int devToolsDockHeight: 360
    property int devToolsDockWidth: 520

    onDevToolsOpenChanged: {
        if (devToolsOpen && devToolsDockSide === "window") {
            devToolsWindow.requestActivate();
            devToolsWindow.raise();
        }
    }
    property int activeTabIndex: 0
    onActiveTabIndexChanged: {
        if (activeTabIndex >= 0 && activeTabIndex < tabsModel.count) {
            tabsModel.setProperty(activeTabIndex, "isAwake", true);
            var cur = tabsModel.get(activeTabIndex);
            if (cur) {
                bridge.currentUrl = cur.url || "";
                window.activeWebTitle = cur.title || "";
            }
            manageMemoryDebounceTimer.restart();
            sessionAutosaveTimer.restart();
        }
    }
    property string activeWebTitle: ""
    property bool splitViewActive: false
    property int splitTabIndex: 1
    onSplitTabIndexChanged: {
        if (splitTabIndex >= 0 && splitTabIndex < tabsModel.count) {
            tabsModel.setProperty(splitTabIndex, "isAwake", true);
            if (splitViewActive && focusedPane === "right") {
                var cur = tabsModel.get(splitTabIndex);
                if (cur) {
                    bridge.currentUrl = cur.url || "";
                    window.activeWebTitle = cur.title || "";
                }
            }
            manageMemoryDebounceTimer.restart();
            sessionAutosaveTimer.restart();
        }
    }
    property string focusedPane: "left" // "left" or "right"

    function toggleSplitView() {
        if (!splitViewActive) {
            splitViewActive = true;
            if (tabsModel.count < 2) {
                var currentUrl = (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? tabsModel.get(activeTabIndex).url : "";
                var targetUrl = (currentUrl && currentUrl.length > 0 && currentUrl !== "about:blank") ? currentUrl : "https://www.google.com";
                var newId = tabsModel.count + 1;
                tabsModel.append({
                    tabId: newId,
                    title: "",
                    url: targetUrl,
                    workspace: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).workspace || "Principal") : "Principal",
                    tabGroup: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).tabGroup || "Geral") : "Geral",
                    favicon: ""
                });
                splitTabIndex = tabsModel.count - 1;
            } else {
                if (splitTabIndex === activeTabIndex) {
                    splitTabIndex = (activeTabIndex + 1) % tabsModel.count;
                }
            }
            focusedPane = "right";
            var currentTab = tabsModel.get(splitTabIndex);
            bridge.currentUrl = currentTab ? currentTab.url : "";
            launcher.isExpanded = false;
            bridge.launcherVisible = true;
        } else {
            splitViewActive = false;
            focusedPane = "left";
            var curTab = tabsModel.get(activeTabIndex);
            bridge.currentUrl = curTab ? curTab.url : "";
        }
    }

    // Gerenciador de Economia de Recursos (Estilo Chrome Memory Saver / Tab Discarding)
    function importTabsBulk(tabsJson, targetWorkspace) {
        try {
            var tabs = JSON.parse(tabsJson || "[]");
            if (!tabs || tabs.length === 0) return;
            var group = targetWorkspace || "Principal";

            var firstEmpty = (tabsModel.count === 1 && (!tabsModel.get(0).url || tabsModel.get(0).url.length === 0));

            for (var i = 0; i < tabs.length; i++) {
                var t = tabs[i];
                if (!t || !t.url) continue;

                if (firstEmpty && i === 0) {
                    tabsModel.setProperty(0, "title", t.title || t.domain || "Nova Aba");
                    tabsModel.setProperty(0, "url", t.url);
                    tabsModel.setProperty(0, "workspace", group);
                    tabsModel.setProperty(0, "tabGroup", t.group || "Geral");
                    tabsModel.setProperty(0, "favicon", "");
                    tabsModel.setProperty(0, "isAwake", true);
                    bridge.currentUrl = t.url;
                    window.activeWebTitle = t.title || t.domain || "";
                } else {
                    // Adiciona APENAS os dados básicos: título, url, domínio, favicon.
                    // isAwake: false mantém o WebEngineView NÃO instanciado (0 processos, 0 RAM, 0 travamento)
                    tabsModel.append({
                        tabId: tabsModel.count + 1,
                        title: t.title || t.domain || "Aba em Espera",
                        url: t.url,
                        workspace: group,
                        tabGroup: t.group || "Geral",
                        favicon: "",
                        isAwake: false
                    });
                }
            }

            window.activeTabIndex = 0;
            var cur = tabsModel.get(0);
            if (cur) {
                bridge.currentUrl = cur.url || "";
                window.activeWebTitle = cur.title || "";
            }
            window.manageTabMemory();
            window.saveCurrentSession();
        } catch(e) {
            console.log("Erro importando abas:", e);
        }
    }

    function saveCurrentSession() {
        try {
            var tabsArr = [];
            for (var i = 0; i < tabsModel.count; i++) {
                var t = tabsModel.get(i);
                if (t && (t.url || t.title)) {
                    tabsArr.push({
                        tabId: t.tabId || (i + 1),
                        title: t.title || "",
                        url: t.url || "",
                        workspace: t.workspace || "Principal",
                        tabGroup: t.tabGroup || "Geral",
                        favicon: t.favicon || ""
                    });
                }
            }
            var sess = {
                workspaces: launcher.workspaces,
                workspaceGroups: launcher.workspaceGroups,
                activeWorkspace: launcher.activeWorkspace,
                activeGroupName: launcher.activeGroupName,
                activeTabIndex: window.activeTabIndex,
                tabs: tabsArr
            };
            bridge.saveSession(JSON.stringify(sess));
        } catch(e) {
            console.log("Erro salvando sessão:", e);
        }
    }

    function restoreSession() {
        try {
            var raw = bridge.loadSession();
            if (!raw || raw.length === 0) return;
            var sess = JSON.parse(raw);
            if (sess.workspaces && Array.isArray(sess.workspaces) && sess.workspaces.length > 0) {
                launcher.workspaces = sess.workspaces;
            }
            if (sess.workspaceGroups && typeof sess.workspaceGroups === "object") {
                launcher.workspaceGroups = sess.workspaceGroups;
            }
            if (sess.activeWorkspace) {
                launcher.activeWorkspace = sess.activeWorkspace;
            }
            if (sess.activeGroupName) {
                launcher.activeGroupName = sess.activeGroupName;
            }
            if (sess.tabs && Array.isArray(sess.tabs) && sess.tabs.length > 0) {
                tabsModel.clear();
                for (var i = 0; i < sess.tabs.length; i++) {
                    var t = sess.tabs[i];
                    tabsModel.append({
                        tabId: t.tabId || (i + 1),
                        title: t.title || "",
                        url: t.url || "",
                        workspace: t.workspace || "Principal",
                        tabGroup: t.tabGroup || "Geral",
                        favicon: t.favicon || "",
                        isAwake: false
                    });
                }
                var targetIdx = (typeof sess.activeTabIndex === "number" && sess.activeTabIndex < tabsModel.count) ? sess.activeTabIndex : 0;
                window.activeTabIndex = targetIdx;
                tabsModel.setProperty(targetIdx, "isAwake", true);
                var cur = tabsModel.get(targetIdx);
                if (cur) {
                    bridge.currentUrl = cur.url || "";
                    window.activeWebTitle = cur.title || "";
                }
                manageMemoryDebounceTimer.restart();
            }
        } catch(e) {
            console.log("Erro restaurando sessão:", e);
        }
    }

    Timer {
        id: sessionAutosaveTimer
        interval: 1500
        repeat: false
        onTriggered: window.saveCurrentSession()
    }

    Timer {
        id: manageMemoryDebounceTimer
        interval: 3000
        repeat: false
        onTriggered: window.manageTabMemory()
    }

    function manageTabMemory() {
        var awakeIndices = [];
        for (var i = 0; i < tabsModel.count; i++) {
            var t = tabsModel.get(i);
            if (t && t.isAwake === true && i !== window.activeTabIndex && (!window.splitViewActive || i !== window.splitTabIndex)) {
                awakeIndices.push(i);
            }
        }
        // Se houver mais de 8 abas em segundo plano ativas, suspende a mais distante para economizar CPU/RAM (Tab Discard)
        if (awakeIndices.length > 8) {
            var farthestIdx = awakeIndices[0];
            var maxDist = -1;
            for (var j = 0; j < awakeIndices.length; j++) {
                var idx = awakeIndices[j];
                var dist = Math.abs(idx - window.activeTabIndex);
                if (dist > maxDist) {
                    maxDist = dist;
                    farthestIdx = idx;
                }
            }
            tabsModel.setProperty(farthestIdx, "isAwake", false);
        }
    }

    // Tabs Model for Multi-tab & Workspace management
    ListModel {
        id: tabsModel
        ListElement {
            tabId: 1
            title: ""
            url: ""  // Inicialmente NADA no fundo (canvas limpo!)
            workspace: "Principal"
            tabGroup: "Geral"
            favicon: ""
            isAwake: true
        }
    }

    // Omarchy Canvas Content with Inactive Opacity Effect
    Item {
        id: rootCanvas
        anchors.fill: parent
        opacity: (window.active || rootMouseDetector.containsMouse) ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }

        // Global Mouse Detection for hover opacity
        MouseArea {
            id: rootMouseDetector
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 0
        }

        // Dedicated web content area that adjusts smoothly when DevTools is docked
        Item {
            id: webCanvasArea
            anchors.top: parent.top
            anchors.bottom: (window.devToolsOpen && window.devToolsDockSide === "bottom") ? devToolsDock.top : parent.bottom
            anchors.left: (window.devToolsOpen && window.devToolsDockSide === "left") ? devToolsDock.right : parent.left
            anchors.right: (window.devToolsOpen && window.devToolsDockSide === "right") ? devToolsDock.left : parent.right

            // 100% CLEAN USEFUL AREA - Zero overlays on the web canvas (Single or Split View)
            Repeater {
                id: tabsRepeater
                model: tabsModel

                delegate: Item {
                    id: tabItemDelegate
                    property var webViewItem: webViewLoader.item
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    onIsLeftPaneChanged: {
                        if (isLeftPane) {
                            if (model.isAwake !== true) tabsModel.setProperty(index, "isAwake", true);
                            if (webViewLoader.item && model.url && model.url.length > 0 && model.url !== "about:blank") {
                                if (webViewLoader.item.url.toString() !== model.url) {
                                    webViewLoader.item.url = model.url;
                                }
                            }
                        }
                    }
                    onIsRightPaneChanged: {
                        if (isRightPane) {
                            if (model.isAwake !== true) tabsModel.setProperty(index, "isAwake", true);
                            if (webViewLoader.item && model.url && model.url.length > 0 && model.url !== "about:blank") {
                                if (webViewLoader.item.url.toString() !== model.url) {
                                    webViewLoader.item.url = model.url;
                                }
                            }
                        }
                    }

                readonly property bool isLeftPane: index === window.activeTabIndex
                readonly property bool isRightPane: window.splitViewActive && index === window.splitTabIndex

                visible: isLeftPane || isRightPane

                // Explicit positioning to guarantee perfect two-pane split with center divider
                x: (!window.splitViewActive || isLeftPane) ? 0 : Math.ceil((parent.width + Theme.borderSize) / 2)
                width: window.splitViewActive ? Math.floor((parent.width - Theme.borderSize) / 2) : parent.width

                // Active focus border in split view
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (window.splitViewActive && ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right"))) ? Theme.accent : "transparent"
                    border.width: 1
                    z: 50
                }

                // Placeholder when tab has no URL loaded yet
                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    visible: !model.url || model.url.length === 0 || model.url === "about:blank"
                    z: 10

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Rectangle {
                            width: 56
                            height: 56
                            radius: 28
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            Glyph {
                                name: "dual"
                                size: 24
                                color: Theme.accent
                                anchors.centerIn: parent
                            }
                        }

                        Text {
                            text: isRightPane ? "Janela Dividida Direita" : "Focus"
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.foreground
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Digite um endereço na barra superior para carregar"
                            font.pixelSize: 12
                            color: Theme.muted
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 40
                    acceptedButtons: Qt.LeftButton
                    propagateComposedEvents: true
                    onPressed: function(mouse) {
                        if (isLeftPane) {
                            window.focusedPane = "left";
                            bridge.currentUrl = model.url;
                            window.activeWebTitle = model.title;
                        } else if (isRightPane) {
                            window.focusedPane = "right";
                            bridge.currentUrl = model.url;
                            window.activeWebTitle = model.title;
                        }
                        mouse.accepted = false;
                    }
                }

                Loader {
                    id: webViewLoader
                    anchors.fill: parent
                    asynchronous: !(isLeftPane || isRightPane)
                    active: (isLeftPane || isRightPane || model.isAwake === true) && (model.url && model.url.length > 0 && model.url !== "about:blank")
                    sourceComponent: webViewComponent
                    onLoaded: {
                        if (item && model.url && model.url.length > 0 && model.url !== "about:blank") {
                            if (item.url.toString() !== model.url) {
                                item.url = model.url;
                            }
                        }
                    }
                }

                Component {
                    id: webViewComponent
                    WebEngineView {
                        id: webView
                        anchors.fill: parent
                        profile: persistentWebProfile
                        url: model.url
                        devToolsView: (window.devToolsOpen && ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")))
                            ? (window.devToolsDockSide === "window" ? windowDevToolsView : dockDevToolsView)
                            : null

                    onNavigationRequested: function(request) {
                        var targetUrl = request.url;
                        var targetString = targetUrl ? targetUrl.toString() : "";
                        var schemeMatch = /^([a-z][a-z0-9+.-]*):/i.exec(targetString);
                        var scheme = schemeMatch ? schemeMatch[1].toLowerCase() : "";
                        if (request.isMainFrame && window.isExternalAuthRequest(targetUrl)) {
                            request.action = WebEngineNavigationRequest.IgnoreRequest;
                            window.handoffAuthentication(webView.url.toString());
                            return;
                        }
                        if (request.isMainFrame && scheme !== "http" && scheme !== "https") {
                            request.action = WebEngineNavigationRequest.IgnoreRequest;
                            bridge.openExternalUrl(targetString);
                        }
                    }

                    onNewWindowRequested: function(request) {
                        var targetUrl = request.requestedUrl ? request.requestedUrl.toString() : "";
                        var isExternalAuth = window.isExternalAuthRequest(request.requestedUrl);
                        if (isExternalAuth && request.userInitiated) {
                            // Authentication providers reject embedded WebViews. Open the
                            // originating app in the system browser so its OAuth state,
                            // cookies, and callback all stay in the same browser session.
                            window.handoffAuthentication(webView.url.toString());
                        } else if (/^https?:\/\//i.test(targetUrl)) {
                            launcher.newTabRequested(targetUrl, "default");
                        }
                    }

                    onUrlChanged: {
                        var strUrl = url.toString();
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            bridge.currentUrl = strUrl;
                        }
                        tabsModel.setProperty(index, "url", strUrl);
                        webView.injectAutofill();
                        webView.runJavaScript("try { Object.defineProperty(navigator, 'webdriver', { get: () => undefined }); } catch(e) {}");
                    }

                    onTitleChanged: {
                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            window.activeWebTitle = title;
                            bridge.pageTitle = title;
                        }
                        tabsModel.setProperty(index, "title", title);
                    }

                    onIconChanged: {
                        var iconStr = icon ? icon.toString() : "";
                        tabsModel.setProperty(index, "favicon", iconStr);
                    }

                    function injectSelectionStyle() {
                        var accentColor = Theme.accent;
                        var bgColor = Theme.background;
                        var js = "(function() {" +
                            "var style = document.getElementById('focus-selection-theme');" +
                            "if (!style) {" +
                            "  style = document.createElement('style');" +
                            "  style.id = 'focus-selection-theme';" +
                            "  (document.head || document.documentElement).appendChild(style);" +
                            "}" +
                            "style.textContent = '::selection { background-color: " + accentColor + " !important; color: " + bgColor + " !important; } " +
                            "::-moz-selection { background-color: " + accentColor + " !important; color: " + bgColor + " !important; }';" +
                            "})();";
                        runJavaScript(js);
                    }

                    function injectAutofill() {
                        var targetUrl = url ? url.toString() : "";
                        if (!targetUrl || targetUrl.startsWith("about:") || targetUrl.startsWith("chrome:")) return;

                        var credsJson = bridge.queryBitwardenLogins(targetUrl);
                        var isUnlocked = bridge.bitwardenUnlocked ? "true" : "false";
                        var isInstalled = bridge.isBitwardenInstalled() ? "true" : "false";

                        var js = "(function() {\n" +
                            "  var creds = " + credsJson + ";\n" +
                            "  var isUnlocked = " + isUnlocked + ";\n" +
                            "  var isInstalled = " + isInstalled + ";\n" +
                            "  window.__focusCreds = creds;\n" +
                            "  window.__focusBwUnlocked = isUnlocked;\n" +
                            "  window.__focusBwInstalled = isInstalled;\n" +
                            "\n" +
                            "  function isLoginField(el) {\n" +
                            "    if (!el || el.tagName !== 'INPUT') return false;\n" +
                            "    var t = (el.type || 'text').toLowerCase();\n" +
                            "    if (t === 'password' || t === 'email') return true;\n" +
                            "    if (t !== 'text' && t !== 'tel') return false;\n" +
                            "    var attrs = [(el.name||''), (el.id||''), (el.autocomplete||''), (el.getAttribute('autocomplete')||''), (el.getAttribute('data-testid')||''), (el.placeholder||''), (el.getAttribute('aria-label')||''), (el.className||'')].join(' ').toLowerCase();\n" +
                            "    return /user|login|email|mail|ident|conta|cpf|usuario|usuário|member|account|auth/.test(attrs);\n" +
                            "  }\n" +
                            "\n" +
                            "  function setVal(input, val) {\n" +
                            "    if (!input || val == null) return;\n" +
                            "    var proto = Object.getPrototypeOf(input);\n" +
                            "    var descriptor = Object.getOwnPropertyDescriptor(proto, 'value') || Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');\n" +
                            "    if (descriptor && descriptor.set) { descriptor.set.call(input, val); } else { input.value = val;\n }\n" +
                            "    input.dispatchEvent(new Event('input', {bubbles:true}));\n" +
                            "    input.dispatchEvent(new Event('change', {bubbles:true}));\n" +
                            "  }\n" +
                            "\n" +
                            "  function fillCredentials(target, c) {\n" +
                            "    if (!c) return;\n" +
                            "    var form = target.form || target.closest('form') || target.parentElement;\n" +
                            "    var passInputs = form ? form.querySelectorAll('input[type=\"password\"]') : document.querySelectorAll('input[type=\"password\"]');\n" +
                            "    var userInputs = form ? form.querySelectorAll('input[type=\"email\"], input[type=\"text\"], input[type=\"tel\"]') : document.querySelectorAll('input[type=\"email\"], input[type=\"text\"], input[type=\"tel\"]');\n" +
                            "    if (target.type === 'password') {\n" +
                            "      setVal(target, c.password || '');\n" +
                            "      var u = null;\n" +
                            "      userInputs.forEach(function(inp) { if (!u && isLoginField(inp) && inp.type !== 'password') u = inp; });\n" +
                            "      if (u) setVal(u, c.username || '');\n" +
                            "    } else {\n" +
                            "      setVal(target, c.username || '');\n" +
                            "      var p = null;\n" +
                            "      passInputs.forEach(function(inp) { if (!p) p = inp; });\n" +
                            "      if (p) setVal(p, c.password || '');\n" +
                            "    }\n" +
                            "  }\n" +
                            "\n" +
                            "  function showMenu(target) {\n" +
                            "    var old = document.getElementById('focus-bw-popup');\n" +
                            "    if (old) old.remove();\n" +
                            "    var r = target.getBoundingClientRect();\n" +
                            "    if (r.width === 0 && r.height === 0) return;\n" +
                            "    var pop = document.createElement('div');\n" +
                            "    pop.id = 'focus-bw-popup';\n" +
                            "    var hasCreds = window.__focusCreds && window.__focusCreds.length > 0;\n" +
                            "    var estHeight = hasCreds ? (60 + window.__focusCreds.length * 44) : 95;\n" +
                            "    var topPos = (r.bottom + 6);\n" +
                            "    if (topPos + estHeight > window.innerHeight && (r.top - estHeight) > 0) {\n" +
                            "      topPos = r.top - estHeight - 6;\n" +
                            "    }\n" +
                            "    var leftPos = Math.max(8, Math.min(r.left, window.innerWidth - 320));\n" +
                            "    pop.style.cssText = 'position:fixed;top:' + topPos + 'px;left:' + leftPos + 'px;min-width:' + Math.max(240, r.width) + 'px;max-width:380px;background:#18181b;color:#f4f4f5;border:1px solid #3f3f46;border-radius:8px;box-shadow:0 12px 30px rgba(0,0,0,0.7);z-index:2147483647;font-family:Inter,-apple-system,sans-serif;font-size:12px;overflow:hidden;padding:4px 0;';\n" +
                            "    var h = '<div style=\"padding:6px 12px;font-size:10px;font-weight:700;letter-spacing:0.5px;color:#a1a1aa;text-transform:uppercase;border-bottom:1px solid #27272a;display:flex;align-items:center;gap:6px;\"><span>🛡️</span><span>Bitwarden</span></div>';\n" +
                            "    if (hasCreds) {\n" +
                            "      window.__focusCreds.forEach(function(c, i) {\n" +
                            "        h += '<div class=\"f-item\" data-i=\"' + i + '\" style=\"display:flex;align-items:center;padding:8px 12px;cursor:pointer;gap:8px;transition:background 0.15s;\">' +\n" +
                            "             '<span style=\"font-size:14px;\">🔑</span>' +\n" +
                            "             '<div style=\"flex:1;overflow:hidden;\"><div style=\"font-weight:600;color:#fafafa;text-overflow:ellipsis;overflow:hidden;white-space:nowrap;\">' + (c.username || 'Conta') + '</div><div style=\"font-size:10px;color:#a1a1aa;\">•••••••• • ' + (c.name || 'Bitwarden') + '</div></div>' +\n" +
                            "             '<span style=\"font-size:9px;background:#27272a;padding:2px 6px;border-radius:4px;color:#60a5fa;font-weight:600;\">Preencher</span></div>';\n" +
                            "      });\n" +
                            "      h += '<div class=\"f-open-vault\" style=\"display:flex;align-items:center;padding:7px 12px;cursor:pointer;gap:6px;border-top:1px solid #27272a;color:#93c5fd;font-size:11px;font-weight:500;transition:background 0.15s;\"><span>🔍</span><span>Buscar outra no cofre...</span></div>';\n" +
                            "    } else if (!window.__focusBwUnlocked) {\n" +
                            "      h += '<div class=\"f-unlock\" style=\"display:flex;align-items:center;padding:10px 12px;cursor:pointer;gap:8px;\"><span style=\"font-size:16px;\">🔒</span><div><div style=\"font-weight:600;color:#60a5fa;\">Desbloquear Bitwarden</div><div style=\"font-size:10px;color:#a1a1aa;\">Clique para autenticar com a Senha Mestra</div></div></div>';\n" +
                            "    } else {\n" +
                            "      h += '<div style=\"padding:10px 12px 6px 12px;color:#a1a1aa;font-size:11px;display:flex;align-items:center;gap:6px;\"><span>ℹ️</span><span>Nenhuma credencial salva para este site.</span></div>' +\n" +
                            "           '<div class=\"f-open-vault\" style=\"display:flex;align-items:center;padding:8px 12px;margin:4px 8px 6px 8px;cursor:pointer;gap:8px;background:#27272a;border-radius:6px;border:1px solid #3f3f46;transition:all 0.15s;\"><span style=\"font-size:15px;\">🔍</span><div><div style=\"font-weight:600;color:#60a5fa;font-size:11px;\">Abrir Cofre Bitwarden</div><div style=\"font-size:10px;color:#d4d4d8;\">Buscar ou copiar senha salva</div></div></div>';\n" +
                            "    }\n" +
                            "    pop.innerHTML = h;\n" +
                            "    document.body.appendChild(pop);\n" +
                            "\n" +
                            "    pop.querySelectorAll('.f-item').forEach(function(el) {\n" +
                            "      el.onmouseenter = function() { el.style.background = '#27272a'; };\n" +
                            "      el.onmouseleave = function() { el.style.background = 'transparent'; };\n" +
                            "      el.onmousedown = function(e) {\n" +
                            "        e.preventDefault();\n" +
                            "        var c = window.__focusCreds[parseInt(el.getAttribute('data-i'))];\n" +
                            "        if (c) fillCredentials(target, c);\n" +
                            "        pop.remove();\n" +
                            "      };\n" +
                            "    });\n" +
                            "\n" +
                            "    var unBtn = pop.querySelector('.f-unlock');\n" +
                            "    if (unBtn) {\n" +
                            "      unBtn.onmouseenter = function() { unBtn.style.background = '#27272a'; };\n" +
                            "      unBtn.onmouseleave = function() { unBtn.style.background = 'transparent'; };\n" +
                            "      unBtn.onmousedown = function(e) {\n" +
                            "        e.preventDefault();\n" +
                            "        console.log('[FOCUS_BITWARDEN_UNLOCK]');\n" +
                            "        pop.remove();\n" +
                            "      };\n" +
                            "    }\n" +
                            "\n" +
                            "    pop.querySelectorAll('.f-open-vault').forEach(function(ov) {\n" +
                            "      ov.onmouseenter = function() { ov.style.background = '#3f3f46'; };\n" +
                            "      ov.onmouseleave = function() { ov.style.background = (ov.classList.contains('f-item') ? 'transparent' : '#27272a'); };\n" +
                            "      ov.onmousedown = function(e) {\n" +
                            "        e.preventDefault();\n" +
                            "        e.stopPropagation();\n" +
                            "        console.log('[FOCUS_BITWARDEN_OPEN_VAULT]');\n" +
                            "        pop.remove();\n" +
                            "      };\n" +
                            "    });\n" +
                            "\n" +
                            "    function closeOut(ev) {\n" +
                            "      if (!pop.contains(ev.target) && ev.target !== target && !target.contains(ev.target)) {\n" +
                            "        pop.remove();\n" +
                            "        document.removeEventListener('mousedown', closeOut, true);\n" +
                            "      }\n" +
                            "    }\n" +
                            "    setTimeout(function() { document.addEventListener('mousedown', closeOut, true); }, 60);\n" +
                            "  }\n" +
                            "\n" +
                            "  // Rastreamento e deteccao de nova senha para salvar no Bitwarden\n" +
                            "  if (!window.__focusAutofillInstalled) {\n" +
                            "    window.__focusAutofillInstalled = true;\n" +
                            "    window.__focusLastUser = '';\n" +
                            "    window.__focusLastPass = '';\n" +
                            "    window.__focusLastSaveTime = 0;\n" +
                            "\n" +
                            "    function trackInput(el) {\n" +
                            "      if (!el || el.tagName !== 'INPUT') return;\n" +
                            "      if (el.type === 'password') {\n" +
                            "        if (el.value) window.__focusLastPass = el.value;\n" +
                            "        var f = el.form || el.closest('form');\n" +
                            "        if (f) {\n" +
                            "          var u = f.querySelector('input[type=\"email\"], input[type=\"text\"], input[type=\"tel\"]');\n" +
                            "          if (u && u.value && u.value.trim().length > 0) window.__focusLastUser = u.value.trim();\n" +
                            "        }\n" +
                            "      } else if (isLoginField(el)) {\n" +
                            "        if (el.value && el.value.trim().length > 0) window.__focusLastUser = el.value.trim();\n" +
                            "      }\n" +
                            "    }\n" +
                            "\n" +
                            "    function findCredentials(originEl) {\n" +
                            "      var u = '';\n" +
                            "      var p = '';\n" +
                            "      var form = originEl ? (originEl.form || originEl.closest('form')) : null;\n" +
                            "      if (form) {\n" +
                            "        var pEl = form.querySelector('input[type=\"password\"]');\n" +
                            "        if (pEl && pEl.value) p = pEl.value;\n" +
                            "        var uEl = form.querySelector('input[type=\"email\"], input[type=\"text\"], input[type=\"tel\"]');\n" +
                            "        if (uEl && uEl.value && uEl.value.trim()) u = uEl.value.trim();\n" +
                            "      }\n" +
                            "      if (!p) {\n" +
                            "        var allPass = document.querySelectorAll('input[type=\"password\"]');\n" +
                            "        for (var i = 0; i < allPass.length; i++) {\n" +
                            "          if (allPass[i].value) { p = allPass[i].value; break; }\n" +
                            "        }\n" +
                            "      }\n" +
                            "      if (!p) p = window.__focusLastPass;\n" +
                            "      if (!u) {\n" +
                            "        var allUsers = document.querySelectorAll('input[type=\"email\"], input[type=\"text\"], input[type=\"tel\"]');\n" +
                            "        for (var j = 0; j < allUsers.length; j++) {\n" +
                            "          if (isLoginField(allUsers[j]) && allUsers[j].value && allUsers[j].value.trim()) {\n" +
                            "            u = allUsers[j].value.trim();\n" +
                            "            break;\n" +
                            "          }\n" +
                            "        }\n" +
                            "      }\n" +
                            "      if (!u) u = window.__focusLastUser;\n" +
                            "      return { username: u, password: p };\n" +
                            "    }\n" +
                            "\n" +
                            "    function triggerSaveIfNew(u, p) {\n" +
                            "      if (!u || !p || p.length < 2) return;\n" +
                            "      var now = Date.now();\n" +
                            "      if (now - window.__focusLastSaveTime < 2500) return;\n" +
                            "      var isExactMatch = false;\n" +
                            "      var isUpdate = false;\n" +
                            "      if (window.__focusCreds && window.__focusCreds.length > 0) {\n" +
                            "        for (var i = 0; i < window.__focusCreds.length; i++) {\n" +
                            "          var c = window.__focusCreds[i];\n" +
                            "          if (c.username && c.username.toLowerCase() === u.toLowerCase()) {\n" +
                            "            if (c.password === p) {\n" +
                            "              isExactMatch = true;\n" +
                            "              break;\n" +
                            "            } else {\n" +
                            "              isUpdate = true;\n" +
                            "            }\n" +
                            "          }\n" +
                            "        }\n" +
                            "      }\n" +
                            "      if (isExactMatch) return;\n" +
                            "      window.__focusLastSaveTime = now;\n" +
                            "      console.log('[FOCUS_BITWARDEN_SAVE]:' + JSON.stringify({\n" +
                            "        url: window.location.href,\n" +
                            "        username: u,\n" +
                            "        password: p,\n" +
                            "        isUpdate: isUpdate\n" +
                            "      }));\n" +
                            "    }\n" +
                            "\n" +
                            "    document.addEventListener('input', function(e) { trackInput(e.target); }, true);\n" +
                            "    document.addEventListener('change', function(e) { trackInput(e.target); }, true);\n" +
                            "\n" +
                            "    document.addEventListener('focusin', function(e) {\n" +
                            "      if (isLoginField(e.target)) showMenu(e.target);\n" +
                            "    }, true);\n" +
                            "    document.addEventListener('click', function(e) {\n" +
                            "      if (isLoginField(e.target)) {\n" +
                            "        showMenu(e.target);\n" +
                            "      } else {\n" +
                            "        var btn = e.target.closest('button, input[type=\"submit\"], input[type=\"button\"], a[role=\"button\"], [role=\"button\"]');\n" +
                            "        if (btn) {\n" +
                            "          var bType = (btn.getAttribute('type') || '').toLowerCase();\n" +
                            "          var bText = (btn.innerText || btn.value || btn.getAttribute('aria-label') || '').toLowerCase();\n" +
                            "          var bTestId = (btn.getAttribute('data-testid') || '').toLowerCase();\n" +
                            "          var isSubmit = (bType === 'submit') ||\n" +
                            "            /entrar|login|log in|sign in|signin|acessar|continuar|continue|conectar|salvar|cadastrar|registrar|confirmar|submit|avancar|prosseguir/.test(bText) ||\n" +
                            "            /login|submit|signin|entrar/.test(bTestId) ||\n" +
                            "            /login|submit|signin|entrar|btn-primary/.test(btn.id || '') ||\n" +
                            "            /login|submit|signin|entrar|btn-primary/.test(btn.className || '');\n" +
                            "          if (isSubmit) {\n" +
                            "            var creds = findCredentials(btn);\n" +
                            "            triggerSaveIfNew(creds.username, creds.password);\n" +
                            "          }\n" +
                            "        }\n" +
                            "      }\n" +
                            "    }, true);\n" +
                            "\n" +
                            "    document.addEventListener('submit', function(e) {\n" +
                            "      var creds = findCredentials(e.target);\n" +
                            "      triggerSaveIfNew(creds.username, creds.password);\n" +
                            "    }, true);\n" +
                            "\n" +
                            "    document.addEventListener('keydown', function(e) {\n" +
                            "      if (e.key === 'Enter') {\n" +
                            "        if (e.target && (e.target.type === 'password' || isLoginField(e.target))) {\n" +
                            "          trackInput(e.target);\n" +
                            "          var creds = findCredentials(e.target);\n" +
                            "          triggerSaveIfNew(creds.username, creds.password);\n" +
                            "        }\n" +
                            "      }\n" +
                            "    }, true);\n" +
                            "  }\n" +
                            "})();";
                        runJavaScript(js);
                    }

                    function translatePage(targetLang) {
                        var lang = targetLang || "pt";
                        var js = "(function() {\n" +
                            "  if (window.google && window.google.translate) {\n" +
                            "    var sel = document.querySelector('.goog-te-combo');\n" +
                            "    if (sel) {\n" +
                            "      sel.value = '" + lang + "';\n" +
                            "      sel.dispatchEvent(new Event('change'));\n" +
                            "    }\n" +
                            "    return;\n" +
                            "  }\n" +
                            "  var el = document.getElementById('google_translate_element');\n" +
                            "  if (!el) {\n" +
                            "    el = document.createElement('div');\n" +
                            "    el.id = 'google_translate_element';\n" +
                            "    el.style.cssText = 'position:fixed;top:16px;right:16px;z-index:2147483647;background:#ffffff;color:#18181b;border:1px solid #ccc;border-radius:8px;padding:6px 12px;box-shadow:0 8px 24px rgba(0,0,0,0.3);font-family:Inter,sans-serif;font-size:12px;';\n" +
                            "    document.body.appendChild(el);\n" +
                            "  }\n" +
                            "  window.googleTranslateElementInit = function() {\n" +
                            "    try {\n" +
                            "      new google.translate.TranslateElement({\n" +
                            "        pageLanguage: 'auto',\n" +
                            "        includedLanguages: 'pt,en,es,fr,de,it,ja,zh-CN,ru',\n" +
                            "        layout: google.translate.TranslateElement.InlineLayout.SIMPLE,\n" +
                            "        autoDisplay: false\n" +
                            "      }, 'google_translate_element');\n" +
                            "      setTimeout(function() {\n" +
                            "        var sel = document.querySelector('.goog-te-combo');\n" +
                            "        if (sel) {\n" +
                            "          sel.value = '" + lang + "';\n" +
                            "          sel.dispatchEvent(new Event('change'));\n" +
                            "        }\n" +
                            "      }, 700);\n" +
                            "    } catch(e) {}\n" +
                            "  };\n" +
                            "  if (!document.getElementById('google-translate-script')) {\n" +
                            "    var s = document.createElement('script');\n" +
                            "    s.id = 'google-translate-script';\n" +
                            "    s.type = 'text/javascript';\n" +
                            "    s.src = 'https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';\n" +
                            "    document.head.appendChild(s);\n" +
                            "  }\n" +
                            "})();";
                        runJavaScript(js);
                    }

                    onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceId) {
                        if (message.indexOf("[FOCUS_BITWARDEN_UNLOCK]") === 0 || message.indexOf("[FOCUS_BITWARDEN_OPEN_VAULT]") === 0) {
                            bitwardenModal.openModal(function() {
                                webView.injectAutofill();
                            });
                        } else if (message.indexOf("[FOCUS_BITWARDEN_SAVE]:") === 0) {
                            try {
                                var raw = message.substring("[FOCUS_BITWARDEN_SAVE]:".length);
                                var cred = JSON.parse(raw);
                                if (cred && cred.username && cred.password) {
                                    savePasswordPrompt.promptSave(cred.url, cred.username, cred.password, cred.isUpdate === true);
                                }
                            } catch(e) {}
                        }
                    }

                    Connections {
                        target: Theme
                        function onAccentChanged() {
                            webView.injectSelectionStyle();
                        }
                    }

                    Connections {
                        target: bridge
                        function onBitwardenStatusChanged() {
                            webView.injectAutofill();
                        }
                    }

                    onLoadingChanged: function(loadRequest) {
                        if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                            webView.runJavaScript("try { Object.defineProperty(navigator, 'webdriver', { get: () => undefined }); } catch(e) {}");
                        }

                        if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                            bridge.isLoading = (loadRequest.status === WebEngineView.LoadStartedStatus);
                        }

                        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            webView.injectSelectionStyle();
                            webView.injectAutofill();

                            var currUrl = webView.url ? webView.url.toString() : "";
                            if (currUrl.indexOf("accounts.google.com") !== -1 || currUrl.indexOf("myaccount.google.com") !== -1 || currUrl.indexOf("google.com") !== -1 || currUrl.indexOf("youtube.com") !== -1) {
                                var checkGoogleScript = "(function() {" +
                                    "try {" +
                                    "  var accLink = document.querySelector('a[aria-label*=\"Google Account\"], a[aria-label*=\"Conta do Google\"], a[href*=\"SignOutOptions\"], button[aria-label*=\"Google Account\"], button[aria-label*=\"Conta do Google\"]');" +
                                    "  var label = accLink ? (accLink.getAttribute('aria-label') || '') : '';" +
                                    "  var name = ''; var email = '';" +
                                    "  if (label) {" +
                                    "    var m = label.match(/:\\s*([^\\n\\r\\(]+)(?:\\s*\\(([^\\)]+)\\))?/);" +
                                    "    if (m) { name = m[1].trim(); if (m[2]) email = m[2].trim(); }" +
                                    "  }" +
                                    "  var img = document.querySelector('a[href*=\"SignOutOptions\"] img, a[aria-label*=\"Google Account\"] img, a[aria-label*=\"Conta do Google\"] img, img[alt*=\"Google Account\"], img[alt*=\"Conta do Google\"]');" +
                                    "  var avatar = img ? img.src : '';" +
                                    "  if (email && email.indexOf('@') !== -1) {" +
                                    "    return JSON.stringify({ isLoggedIn: true, name: name, email: email, avatar: avatar });" +
                                    "  }" +
                                    "} catch(e) {}" +
                                    "return '';" +
                                    "})();";
                                webView.runJavaScript(checkGoogleScript, function(result) {
                                    if (result && result.length > 5) {
                                        bridge.saveGoogleAccount(result);
                                    }
                                });
                            }
                        }

                        // Auto fallback bidirecional: Se falhou com www tenta sem www, se falhou sem www tenta com www
                        if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                            var failedUrl = loadRequest.url ? loadRequest.url.toString() : "";
                            if (failedUrl && failedUrl.startsWith("https://www.")) {
                                var noWwwUrl = failedUrl.replace("https://www.", "https://");
                                console.log("[Focus] Falha ao carregar com www, tentando sem www: " + noWwwUrl);
                                webView.url = noWwwUrl;
                                tabsModel.setProperty(index, "url", noWwwUrl);
                                if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                                    bridge.currentUrl = noWwwUrl;
                                }
                            } else if (failedUrl && failedUrl.startsWith("https://") && !failedUrl.startsWith("https://www.")) {
                                var retryUrl = failedUrl.replace("https://", "https://www.");
                                console.log("[Focus] Falha ao carregar sem www, tentando com www: " + retryUrl);
                                webView.url = retryUrl;
                                tabsModel.setProperty(index, "url", retryUrl);
                                if ((isLeftPane && window.focusedPane === "left") || (isRightPane && window.focusedPane === "right")) {
                                    bridge.currentUrl = retryUrl;
                                }
                            }
                        }
                    }

                    onContextMenuRequested: function(request) {
                        request.accepted = true;
                        var pos = mapToItem(rootCanvas, request.position.x, request.position.y);
                        contextMenu.showAt(request, webView, pos);
                    }
                }
            }
        }
    }

            // Vertical Divider for Split View
            Rectangle {
                id: splitDivider
                width: Theme.borderSize
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.border
                visible: window.splitViewActive
                z: 60
            }
        }

        // Chrome DevTools Dock Panel (Bottom / Right / Left)
        Rectangle {
            id: devToolsDock
            visible: window.devToolsOpen && window.devToolsDockSide !== "window"
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            clip: true
            z: 80

            anchors.bottom: parent.bottom
            anchors.top: window.devToolsDockSide === "bottom" ? undefined : parent.top
            anchors.left: window.devToolsDockSide === "right" ? undefined : parent.left
            anchors.right: window.devToolsDockSide === "left" ? undefined : parent.right

            width: window.devToolsDockSide === "bottom" ? parent.width : window.devToolsDockWidth
            height: window.devToolsDockSide === "bottom" ? window.devToolsDockHeight : parent.height

            // Resizer handle for Bottom dock
            MouseArea {
                visible: window.devToolsDockSide === "bottom"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 5
                cursorShape: Qt.SizeVerCursor
                z: 20
                property int startY: 0
                property int startH: 0
                onPressed: function(mouse) {
                    startY = mouse.y;
                    startH = window.devToolsDockHeight;
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = mouse.y - startY;
                        window.devToolsDockHeight = Math.max(180, Math.min(startH - delta, window.height - 120));
                    }
                }
            }

            // Resizer handle for Right dock
            MouseArea {
                visible: window.devToolsDockSide === "right"
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 5
                cursorShape: Qt.SizeHorCursor
                z: 20
                property int startX: 0
                property int startW: 0
                onPressed: function(mouse) {
                    startX = mouse.x;
                    startW = window.devToolsDockWidth;
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = mouse.x - startX;
                        window.devToolsDockWidth = Math.max(280, Math.min(startW - delta, window.width - 200));
                    }
                }
            }

            // Resizer handle for Left dock
            MouseArea {
                visible: window.devToolsDockSide === "left"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 5
                cursorShape: Qt.SizeHorCursor
                z: 20
                property int startX: 0
                property int startW: 0
                onPressed: function(mouse) {
                    startX = mouse.x;
                    startW = window.devToolsDockWidth;
                }
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        var delta = mouse.x - startX;
                        window.devToolsDockWidth = Math.max(280, Math.min(startW + delta, window.width - 200));
                    }
                }
            }

            Column {
                anchors.fill: parent

                DevToolsHeader {
                    id: dockDevToolsHeader
                    width: parent.width
                    currentDockSide: window.devToolsDockSide
                    inspectedTitle: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).title || "") : ""
                    inspectedUrl: bridge.currentUrl

                    onDockSideRequested: function(side) {
                        window.devToolsDockSide = side;
                        if (side === "window") {
                            devToolsWindow.requestActivate();
                            devToolsWindow.raise();
                        }
                    }
                    onCloseRequested: function() {
                        window.devToolsOpen = false;
                    }
                }

                WebEngineView {
                    id: dockDevToolsView
                    width: parent.width
                    height: Math.max(0, parent.height - 32)
                    backgroundColor: Theme.background

                    onLoadingChanged: function(loadRequest) {
                        if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                            runJavaScript("try { if (window.Common && window.Common.Settings) Common.Settings.moduleSetting('uiTheme').set('dark'); } catch(e) {}");
                        }
                    }
                }
            }
        }
    }

    // Top Edge Trigger Zone (Hovering at the extreme top edge reveals the launcher)
    MouseArea {
        id: topHoverTrigger
        height: 4
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        hoverEnabled: true
        z: 100

        onEntered: {
            bridge.launcherVisible = true
        }
    }

    // Expandable Top Launcher - The SOLE point of interaction
    Launcher {
        id: launcher
        tabsModel: tabsModel
        activeTabIndex: (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex

        onFlipSplitRequested: window.toggleSplitView()

        onOpenUrlInTab: function(url) {
            var targetIndex = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            if (tabsModel.count > 0 && targetIndex < tabsModel.count) {
                tabsModel.setProperty(targetIndex, "url", url);
                bridge.currentUrl = url;
                var item = tabsRepeater.itemAt(targetIndex);
                if (item && item.webViewItem) {
                    item.webViewItem.url = url;
                }
            }
        }

        onNewTabRequested: function(url, workspace) {
            var newId = tabsModel.count + 1;
            tabsModel.append({
                tabId: newId,
                title: url ? "" : "Nova Aba",
                url: url,
                workspace: workspace || "Principal",
                tabGroup: "Geral",
                favicon: "",
                isAwake: true
            });
            if (window.splitViewActive && window.focusedPane === "right") {
                window.splitTabIndex = tabsModel.count - 1;
            } else {
                window.activeTabIndex = tabsModel.count - 1;
            }
            bridge.currentUrl = url;
            window.manageTabMemory();
            sessionAutosaveTimer.restart();
        }

        onNewTabInGroupRequested: function(url, workspace, tabGroup) {
            var newId = tabsModel.count + 1;
            tabsModel.append({
                tabId: newId,
                title: url ? "" : "Nova Aba",
                url: url,
                workspace: workspace || "Principal",
                tabGroup: tabGroup || "Geral",
                favicon: "",
                isAwake: true
            });
            if (window.splitViewActive && window.focusedPane === "right") {
                window.splitTabIndex = tabsModel.count - 1;
            } else {
                window.activeTabIndex = tabsModel.count - 1;
            }
            bridge.currentUrl = url;
            window.manageTabMemory();
            sessionAutosaveTimer.restart();
        }

        onSwitchTabRequested: function(index) {
            if (index >= 0 && index < tabsModel.count) {
                if (window.splitViewActive && window.focusedPane === "right") {
                    if (index === window.activeTabIndex && tabsModel.count > 1) {
                        window.activeTabIndex = window.splitTabIndex;
                    }
                    window.splitTabIndex = index;
                } else if (window.splitViewActive && window.focusedPane === "left") {
                    if (index === window.splitTabIndex && tabsModel.count > 1) {
                        window.splitTabIndex = window.activeTabIndex;
                    }
                    window.activeTabIndex = index;
                } else {
                    window.activeTabIndex = index;
                }
                var curIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
                tabsModel.setProperty(curIdx, "isAwake", true);
                var currentTab = tabsModel.get(curIdx);
                bridge.currentUrl = currentTab ? currentTab.url : "";
                window.activeWebTitle = currentTab ? currentTab.title : "";
                window.manageTabMemory();
                sessionAutosaveTimer.restart();
            }
        }

        onCloseTabRequested: function(index) {
            if (tabsModel.count > 1) {
                tabsModel.remove(index);
                if (window.activeTabIndex >= tabsModel.count) {
                    window.activeTabIndex = tabsModel.count - 1;
                }
                if (window.splitTabIndex >= tabsModel.count) {
                    window.splitTabIndex = Math.max(0, tabsModel.count - 1);
                }
                var activeTab = tabsModel.get(window.activeTabIndex);
                bridge.currentUrl = activeTab.url;
                window.activeWebTitle = activeTab.title;
            } else if (tabsModel.count === 1) {
                tabsModel.setProperty(0, "url", "");
                tabsModel.setProperty(0, "title", "");
                tabsModel.setProperty(0, "favicon", "");
                bridge.currentUrl = "";
                window.activeWebTitle = "";
            }
            sessionAutosaveTimer.restart();
        }

        onWebViewAction: function(action) {
            var targetIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            var activeItem = tabsRepeater.itemAt(targetIdx);
            if (activeItem && activeItem.webViewItem) {
                var ch = activeItem.webViewItem;
                if (action === "back") ch.goBack();
                else if (action === "forward") ch.goForward();
                else if (action === "reload") ch.reload();
                else if (action === "stop") ch.stop();
            }
        }

        onRequestBitwardenUnlock: bitwardenModal.openModal()
        onRequestHistoryModal: historyModal.openModal()

        onTranslatePageRequested: function(targetLang) {
            var targetIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            var activeItem = tabsRepeater.itemAt(targetIdx);
            if (activeItem && activeItem.webViewItem) {
                activeItem.webViewItem.translatePage(targetLang);
            }
        }
    }

    SettingsModal {
        id: settingsModal
        onRequestBitwardenUnlock: bitwardenModal.openModal()
        onLanguageChanged: function(langCode) {
            window.currentAppLanguage = langCode;
            persistentWebProfile.httpAcceptLanguage = window.mapAcceptLanguage(langCode);
            var shortLang = langCode.split("-")[0];
            var targetIdx = (window.splitViewActive && window.focusedPane === "right") ? window.splitTabIndex : window.activeTabIndex;
            var activeItem = tabsRepeater.itemAt(targetIdx);
            if (activeItem && activeItem.webViewItem) {
                activeItem.webViewItem.translatePage(shortLang);
                var curUrl = activeItem.webViewItem.url ? activeItem.webViewItem.url.toString() : "";
                if (curUrl && curUrl.length > 0 && curUrl !== "about:blank" && !curUrl.startsWith("chrome:")) {
                    activeItem.webViewItem.reload();
                }
            }
        }
    }

    // Default Browser Prompt Modal for First Launch
    DefaultBrowserPrompt {
        id: defaultBrowserPrompt
    }

    // Bitwarden Master Password and Account Modal
    BitwardenModal {
        id: bitwardenModal
        onOpenUrlRequested: function(url) {
            launcher.newTabRequested(url, "default");
        }
    }

    // Floating Navigation History Modal
    HistoryModal {
        id: historyModal
        onOpenUrlRequested: function(url) {
            launcher.openUrlInTab(url);
        }
        onNewTabRequested: function(url) {
            launcher.newTabRequested(url, "Histórico");
        }
    }

    // Google Password Manager Style Save Password Bubble
    SavePasswordPrompt {
        id: savePasswordPrompt
    }

    // Omarchy-Themed Context Menu
    ContextMenu {
        id: contextMenu
    }

    // Chrome Developer Tools Dedicated Window (Undocked / Secondary Window Mode)
    Window {
        id: devToolsWindow
        title: "Developer Tools - Focus"
        width: 1040
        height: 720
        minimumWidth: 480
        minimumHeight: 300
        color: Theme.background
        visible: window.devToolsOpen && window.devToolsDockSide === "window"

        onClosing: function(close) {
            window.devToolsOpen = false;
        }

        DevToolsHeader {
            id: winDevToolsHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            currentDockSide: window.devToolsDockSide
            inspectedTitle: (tabsModel.count > 0 && activeTabIndex < tabsModel.count) ? (tabsModel.get(activeTabIndex).title || "") : ""
            inspectedUrl: bridge.currentUrl

            onDockSideRequested: function(side) {
                window.devToolsDockSide = side;
            }
            onCloseRequested: function() {
                window.devToolsOpen = false;
            }
        }

        WebEngineView {
            id: windowDevToolsView
            anchors.top: winDevToolsHeader.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            backgroundColor: Theme.background

            onLoadingChanged: function(loadRequest) {
                if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                    runJavaScript("try { if (window.Common && window.Common.Settings) Common.Settings.moduleSetting('uiTheme').set('dark'); } catch(e) {}");
                }
            }
        }

        Shortcut {
            sequence: "F12"
            onActivated: window.devToolsOpen = false
        }
        Shortcut {
            sequence: "Ctrl+Shift+I"
            onActivated: window.devToolsOpen = false
        }
        Shortcut {
            sequence: "Ctrl+Shift+J"
            onActivated: window.devToolsOpen = false
        }
        Shortcut {
            sequence: "Ctrl+Shift+C"
            onActivated: window.devToolsOpen = false
        }
    }

    // Global Window Shortcuts (Active window-wide, always intercepts regardless of webView focus)
    Shortcut {
        sequence: "Space"
        enabled: !bridge.launcherVisible && !bridge.settingsVisible
        onActivated: bridge.launcherVisible = true
    }

    Shortcut {
        sequence: "Alt+Space"
        onActivated: bridge.launcherVisible = !bridge.launcherVisible
    }

    Shortcut {
        sequence: "Ctrl+Space"
        onActivated: bridge.launcherVisible = !bridge.launcherVisible
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: bridge.launcherVisible = true
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: {
            launcher.createNewTab("");
            launcher.isExpanded = true;
            bridge.launcherVisible = true;
        }
    }

    Shortcut {
        sequence: "F12"
        onActivated: window.devToolsOpen = !window.devToolsOpen
    }

    Shortcut {
        sequence: "Ctrl+Shift+I"
        onActivated: window.devToolsOpen = !window.devToolsOpen
    }

    Shortcut {
        sequence: "Ctrl+Shift+J"
        onActivated: window.devToolsOpen = !window.devToolsOpen
    }

    Shortcut {
        sequence: "Ctrl+Shift+C"
        onActivated: window.devToolsOpen = !window.devToolsOpen
    }

    Shortcut {
        sequence: "Ctrl+,"
        onActivated: bridge.settingsVisible = true
    }

    Shortcut {
        sequence: "Ctrl+R"
        onActivated: launcher.webViewAction("reload")
    }

    Shortcut {
        sequence: "F5"
        onActivated: launcher.webViewAction("reload")
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: true
        onActivated: window.handleEscapeKey()
    }

    Rectangle {
        z: 2000
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: Math.min(parent.width - 32, 460)
        height: 62
        radius: Theme.cornerRadius > 0 ? Theme.cornerRadius : 10
        color: Theme.surface
        border.color: Theme.accent
        border.width: 1
        visible: window.externalAuthNoticeVisible
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            text: "O login abriu no navegador externo. Use a extensão Bitwarden desse navegador; o cofre integrado do Focus não acessa outras janelas."
        }
    }

    Connections {
        target: bridge
        function onCurrentUrlChanged() {
            if (tabsModel.count > 0 && window.activeTabIndex < tabsModel.count) {
                var currentTab = tabsModel.get(window.activeTabIndex);
                if (currentTab.url !== bridge.currentUrl && bridge.currentUrl.length > 0) {
                    tabsModel.setProperty(window.activeTabIndex, "url", bridge.currentUrl);
                }
            }
        }
        function onRequestBitwardenModal() {
            bitwardenModal.openModal();
        }
    }
}
