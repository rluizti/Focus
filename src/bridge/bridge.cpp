#include "bridge.h"

#include <QGuiApplication>
#include <QFont>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#include <QtWebEngineCore/QWebEngineExtensionManager>
#include <QtWebEngineCore/QWebEngineExtensionInfo>
#include <QWebEngineProfile>
#include <QWebEngineSettings>
#include <QStandardPaths>
#include <QDir>
#include <QProcess>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QFile>
#include <QTextStream>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDateTime>
#include <QUrl>
#include <iostream>

FocusBridge *FocusBridge::s_instance = nullptr;

FocusBridge::FocusBridge(QObject *parent) : QObject(parent) {
    s_instance = this;
    m_callbacks = {nullptr, nullptr, nullptr, nullptr};
    restoreSessionFromDisk();
}

FocusBridge* FocusBridge::instance() {
    if (!s_instance) {
        s_instance = new FocusBridge();
    }
    return s_instance;
}

void FocusBridge::setCallbacks(RustCallbacks callbacks) {
    m_callbacks = callbacks;
}

void FocusBridge::setThemeJson(const QString &val) {
    if (m_themeJson != val) {
        m_themeJson = val;
        emit themeJsonChanged();
    }
}

void FocusBridge::setConfigJson(const QString &val) {
    if (m_configJson != val) {
        m_configJson = val;
        emit configJsonChanged();
    }
}

void FocusBridge::setBookmarksJson(const QString &val) {
    if (m_bookmarksJson != val) {
        m_bookmarksJson = val;
        emit bookmarksJsonChanged();
    }
}

void FocusBridge::setHistoryJson(const QString &val) {
    if (m_historyJson != val) {
        m_historyJson = val;
        emit historyJsonChanged();
    }
}

void FocusBridge::setCurrentEngine(const QString &val) {
    if (m_currentEngine != val) {
        m_currentEngine = val;
        emit currentEngineChanged();
    }
}

void FocusBridge::setCurrentUrl(const QString &val) {
    if (m_currentUrl != val) {
        m_currentUrl = val;
        emit currentUrlChanged();
    }
}

void FocusBridge::setPageTitle(const QString &val) {
    if (m_pageTitle != val) {
        m_pageTitle = val;
        emit pageTitleChanged();
    }
}

void FocusBridge::setIsLoading(bool val) {
    if (m_isLoading != val) {
        m_isLoading = val;
        emit isLoadingChanged();
    }
}

void FocusBridge::setLoadProgress(qreal val) {
    if (m_loadProgress != val) {
        m_loadProgress = val;
        emit loadProgressChanged();
    }
}

void FocusBridge::setLauncherVisible(bool val) {
    if (m_launcherVisible != val) {
        m_launcherVisible = val;
        emit launcherVisibleChanged();
    }
}

void FocusBridge::setSettingsVisible(bool val) {
    if (m_settingsVisible != val) {
        m_settingsVisible = val;
        emit settingsVisibleChanged();
    }
}

void FocusBridge::saveConfig(const QString &json) {
    m_configJson = json;
    emit configJsonChanged();

    // Dynamically update Accept-Language in WebEngine profile if language was changed
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (doc.isObject()) {
        QString lang = doc.object().value("language").toString();
        if (!lang.isEmpty()) {
            QWebEngineProfile::defaultProfile()->setHttpAcceptLanguage(lang);
        }
    }

    if (m_callbacks.onConfigSaved) {
        QByteArray utf8 = json.toUtf8();
        m_callbacks.onConfigSaved(utf8.constData());
    }
}

QString FocusBridge::passwordsJson() const {
    QString path = QDir::homePath() + "/.config/focus/passwords.json";
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        return QString::fromUtf8(file.readAll());
    }
    return "[]";
}

void FocusBridge::saveCredential(const QString &url, const QString &username, const QString &password) {
    QString configDir = QDir::homePath() + "/.config/focus";
    QDir().mkpath(configDir);
    QString path = configDir + "/passwords.json";

    QJsonArray arr;
    QFile inFile(path);
    if (inFile.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(inFile.readAll());
        if (doc.isArray()) {
            arr = doc.array();
        }
        inFile.close();
    }

    QString domain = url;
    QUrl parsed(url.startsWith("http") ? url : ("https://" + url));
    if (!parsed.host().isEmpty()) {
        domain = parsed.host();
    }

    QJsonObject obj;
    obj["id"] = QString::number(QDateTime::currentMSecsSinceEpoch());
    obj["url"] = url;
    obj["domain"] = domain;
    obj["username"] = username;
    obj["password"] = password;
    obj["date"] = QDate::currentDate().toString("yyyy-MM-dd");

    arr.prepend(obj);

    QFile outFile(path);
    if (outFile.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(arr);
        outFile.write(doc.toJson(QJsonDocument::Indented));
        outFile.close();
    }

    emit passwordsJsonChanged();
}

void FocusBridge::deleteCredential(const QString &id) {
    QString path = QDir::homePath() + "/.config/focus/passwords.json";
    QFile inFile(path);
    if (!inFile.open(QIODevice::ReadOnly)) return;

    QJsonDocument doc = QJsonDocument::fromJson(inFile.readAll());
    inFile.close();
    if (!doc.isArray()) return;

    QJsonArray oldArr = doc.array();
    QJsonArray newArr;
    for (const QJsonValue &val : oldArr) {
        if (val.toObject().value("id").toString() != id) {
            newArr.append(val);
        }
    }

    QFile outFile(path);
    if (outFile.open(QIODevice::WriteOnly)) {
        QJsonDocument outDoc(newArr);
        outFile.write(outDoc.toJson(QJsonDocument::Indented));
        outFile.close();
    }

    emit passwordsJsonChanged();
}

int FocusBridge::importPasswordsFromCsv(const QString &csvPath) {
    QFile file(csvPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return -1;
    }

    QString configDir = QDir::homePath() + "/.config/focus";
    QDir().mkpath(configDir);
    QString path = configDir + "/passwords.json";

    QJsonArray arr;
    QFile inFile(path);
    if (inFile.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(inFile.readAll());
        if (doc.isArray()) arr = doc.array();
        inFile.close();
    }

    QTextStream in(&file);
    int importedCount = 0;
    bool isFirstLine = true;
    int urlCol = 1, userCol = 2, passCol = 3;

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;

        QStringList parts = line.split(",");
        if (isFirstLine) {
            isFirstLine = false;
            for (int i = 0; i < parts.size(); ++i) {
                QString col = parts[i].toLower().remove('"').trimmed();
                if (col == "url") urlCol = i;
                else if (col == "username") userCol = i;
                else if (col == "password") passCol = i;
            }
            continue;
        }

        if (parts.size() > qMax(urlCol, qMax(userCol, passCol))) {
            QString url = parts[urlCol].remove('"').trimmed();
            QString user = parts[userCol].remove('"').trimmed();
            QString pass = parts[passCol].remove('"').trimmed();

            if (!url.isEmpty() && !user.isEmpty()) {
                QString domain = url;
                QUrl parsed(url.startsWith("http") ? url : ("https://" + url));
                if (!parsed.host().isEmpty()) domain = parsed.host();

                QJsonObject obj;
                obj["id"] = QString::number(QDateTime::currentMSecsSinceEpoch()) + "_" + QString::number(importedCount);
                obj["url"] = url;
                obj["domain"] = domain;
                obj["username"] = user;
                obj["password"] = pass;
                obj["date"] = QDate::currentDate().toString("yyyy-MM-dd");

                arr.prepend(obj);
                importedCount++;
            }
        }
    }

    file.close();

    QFile outFile(path);
    if (outFile.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(arr);
        outFile.write(doc.toJson(QJsonDocument::Indented));
        outFile.close();
    }

    emit passwordsJsonChanged();
    return importedCount;
}

void FocusBridge::syncChrome() {
    if (m_callbacks.onChromeSync && m_callbacks.freeString) {
        char *b_str = nullptr;
        char *h_str = nullptr;
        m_callbacks.onChromeSync(&b_str, &h_str);
        if (b_str) {
            setBookmarksJson(QString::fromUtf8(b_str));
            m_callbacks.freeString(b_str);
        }
        if (h_str) {
            setHistoryJson(QString::fromUtf8(h_str));
            m_callbacks.freeString(h_str);
        }
    }
}

void FocusBridge::switchEngine(const QString &engine, const QString &url) {
    setCurrentEngine(engine);
    if (m_callbacks.onSwitchEngine) {
        QByteArray eng = engine.toUtf8();
        QByteArray u = url.toUtf8();
        m_callbacks.onSwitchEngine(eng.constData(), u.constData());
    }
}

void FocusBridge::launchFirefox(const QString &url) {
    // Try zen-browser, firefox, or librewolf
    QStringList candidates = {"zen-browser", "firefox", "librewolf", "waterfox"};
    for (const QString &bin : candidates) {
        if (!QStandardPaths::findExecutable(bin).isEmpty()) {
            QString target = url.isEmpty() ? "https://www.google.com" : url;
            QProcess::startDetached(bin, QStringList() << target);
            return;
        }
    }
}

void FocusBridge::initThemeWatcher() {
    m_themeWatcher = new QFileSystemWatcher(this);
    QString stateDir = QDir::homePath() + "/.local/state/omarchy/current";
    QString themeNamePath = stateDir + "/theme.name";
    QString colorsPath = stateDir + "/theme/colors.toml";

    if (QFile::exists(themeNamePath)) m_themeWatcher->addPath(themeNamePath);
    if (QFile::exists(colorsPath)) m_themeWatcher->addPath(colorsPath);
    if (QDir(stateDir).exists()) m_themeWatcher->addPath(stateDir);

    connect(m_themeWatcher, &QFileSystemWatcher::fileChanged, this, &FocusBridge::onThemeFilesChanged);
    connect(m_themeWatcher, &QFileSystemWatcher::directoryChanged, this, &FocusBridge::onThemeFilesChanged);

    m_themeTimer = new QTimer(this);
    connect(m_themeTimer, &QTimer::timeout, this, &FocusBridge::checkThemeUpdates);
    m_themeTimer->start(600); // 600ms polling guarantees detection even with atomic symlink swaps
}

void FocusBridge::onThemeFilesChanged() {
    reloadThemeFromDisk();
}

void FocusBridge::checkThemeUpdates() {
    QString themeNamePath = QDir::homePath() + "/.local/state/omarchy/current/theme.name";
    QFile file(themeNamePath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString currentName = QString::fromUtf8(file.readAll()).trimmed();
        file.close();
        if (!currentName.isEmpty() && currentName != m_lastThemeName) {
            m_lastThemeName = currentName;
            reloadThemeFromDisk();
        }
    }
}

void FocusBridge::reloadThemeFromDisk() {
    QString colorsPath = QDir::homePath() + "/.local/state/omarchy/current/theme/colors.toml";
    QFile file(colorsPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QMap<QString, QString> map;
    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        int eq = line.indexOf('=');
        if (eq > 0) {
            QString key = line.left(eq).trimmed();
            QString val = line.mid(eq + 1).trimmed();
            if (val.startsWith('"') && val.endsWith('"') && val.length() >= 2) {
                val = val.mid(1, val.length() - 2);
            }
            map[key] = val;
        }
    }
    file.close();

    // Read rounding from theme's hyprland.lua (e.g. rounding = 6)
    int rounding = 6;
    QString hyprPath = QDir::homePath() + "/.local/state/omarchy/current/theme/hyprland.lua";
    QFile hyprFile(hyprPath);
    if (hyprFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream hyprIn(&hyprFile);
        while (!hyprIn.atEnd()) {
            QString hLine = hyprIn.readLine().trimmed();
            if (hLine.startsWith("rounding") && !hLine.startsWith("rounding_power")) {
                int hEq = hLine.indexOf('=');
                if (hEq > 0) {
                    QString val = hLine.mid(hEq + 1).trimmed();
                    if (val.endsWith(',')) val.chop(1);
                    rounding = val.trimmed().toInt();
                    break;
                }
            }
        }
        hyprFile.close();
    }

    QJsonObject obj;
    obj["mode"] = map.value("mode", "dark");
    obj["background"] = map.value("background", "#0c0b0c");
    obj["surface"] = map.value("dark_background", map.value("background", "#121113"));
    obj["surface_variant"] = map.value("muted", "#1a191c");
    obj["foreground"] = map.value("foreground", "#FAFCFB");
    obj["dim_foreground"] = map.value("dark_foreground", "#8f8a8e");
    obj["accent"] = map.value("accent", "#b59790");
    obj["border"] = map.value("active_border_color", "#2d2a2c");
    obj["active_border"] = map.value("accent", map.value("active_border_color", "#ff9f0a"));
    obj["border_size"] = 2;
    obj["selection"] = map.value("selection", "#383335");
    obj["red"] = map.value("red", "#c38b7b");
    obj["green"] = map.value("green", "#87a9b0");
    obj["blue"] = map.value("blue", "#b59790");
    obj["font_family"] = "Inter, 'Liberation Sans', sans-serif";
    obj["corner_radius"] = rounding; // Follows Omarchy theme rounding (0 for sharp, 6/8/12 for rounded)

    QJsonDocument doc(obj);
    QString jsonStr = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    setThemeJson(jsonStr);
}

void FocusBridge::toggleLauncher() {
    setLauncherVisible(!m_launcherVisible);
}

void FocusBridge::toggleSettings() {
    setSettingsVisible(!m_settingsVisible);
}

void FocusBridge::closeBrowser() {
    QGuiApplication::quit();
}

bool FocusBridge::isBitwardenInstalled() const {
    return QFile::exists("/usr/bin/bitwarden-desktop") || QFile::exists("/usr/bin/bitwarden") || QFile::exists("/usr/bin/bw");
}

void FocusBridge::openBitwarden() {
    if (QFile::exists("/usr/bin/bitwarden-desktop")) {
        QProcess::startDetached("/usr/bin/bitwarden-desktop", QStringList());
    } else if (QFile::exists("/usr/bin/bitwarden")) {
        QProcess::startDetached("/usr/bin/bitwarden", QStringList());
    } else if (QFile::exists("/usr/bin/bw")) {
        QProcess::startDetached("xdg-open", QStringList() << "https://vault.bitwarden.com");
    }
}

QString FocusBridge::getBitwardenStatus() {
    return getBitwardenCliStatus();
}

bool FocusBridge::isBitwardenUnlocked() const {
    return !m_bwSession.isEmpty();
}

QString FocusBridge::getBitwardenCliStatus() {
    if (!QFile::exists("/usr/bin/bw")) {
        return "not_installed";
    }
    if (!m_bwSession.isEmpty()) {
        return "unlocked";
    }
    QProcess proc;
    proc.start("/usr/bin/bw", QStringList() << "status");
    if (proc.waitForFinished(1500)) {
        QByteArray out = proc.readAllStandardOutput().trimmed();
        QJsonDocument doc = QJsonDocument::fromJson(out);
        if (doc.isObject()) {
            return doc.object().value("status").toString("locked");
        }
    }
    return "locked";
}

QString FocusBridge::unlockBitwarden(const QString &password) {
    if (!QFile::exists("/usr/bin/bw")) {
        return "Bitwarden CLI (/usr/bin/bw) não encontrado.";
    }
    QProcess proc;
    proc.start("/usr/bin/bw", QStringList() << "unlock" << password << "--raw");
    if (!proc.waitForFinished(8000)) {
        return "Tempo limite excedido ao desbloquear o Bitwarden.";
    }
    if (proc.exitCode() == 0) {
        QString session = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        saveSessionToDisk(session);
        return QString();
    } else {
        QString err = QString::fromUtf8(proc.readAllStandardError()).trimmed();
        if (err.isEmpty()) err = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (err.isEmpty()) err = "Senha mestra incorreta.";
        return err;
    }
}

QString FocusBridge::loginBitwarden(const QString &email, const QString &password) {
    if (!QFile::exists("/usr/bin/bw")) {
        return "Bitwarden CLI (/usr/bin/bw) não encontrado.";
    }
    QProcess proc;
    proc.start("/usr/bin/bw", QStringList() << "login" << email << password << "--raw");
    if (!proc.waitForFinished(12000)) {
        return "Tempo limite excedido ao conectar ao Bitwarden.";
    }
    if (proc.exitCode() == 0) {
        QString session = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        saveSessionToDisk(session);
        return QString();
    } else {
        QString err = QString::fromUtf8(proc.readAllStandardError()).trimmed();
        if (err.isEmpty()) err = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        if (err.isEmpty()) err = "Falha ao autenticar no Bitwarden.";
        return err;
    }
}

void FocusBridge::lockBitwarden() {
    m_bwSession.clear();
    qunsetenv("BW_SESSION");
    QString path = QDir::homePath() + "/.config/focus/bw_session";
    QFile::remove(path);
    if (QFile::exists("/usr/bin/bw")) {
        QProcess proc;
        proc.start("/usr/bin/bw", QStringList() << "lock");
        proc.waitForFinished(1500);
    }
    emit bitwardenStatusChanged();
}

void FocusBridge::restoreSessionFromDisk() {
    QString configDir = QDir::homePath() + "/.config/focus";
    QString path = configDir + "/bw_session";
    QFile file(path);
    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QString s = QString::fromUtf8(file.readAll()).trimmed();
        file.close();
        if (!s.isEmpty()) {
            m_bwSession = s;
            qputenv("BW_SESSION", s.toUtf8());
            emit bitwardenStatusChanged();
        }
    }
}

void FocusBridge::saveSessionToDisk(const QString &session) {
    m_bwSession = session;
    qputenv("BW_SESSION", session.toUtf8());
    QString configDir = QDir::homePath() + "/.config/focus";
    QDir().mkpath(configDir);
    QString path = configDir + "/bw_session";
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        file.write(session.toUtf8());
        file.close();
    }
    emit bitwardenStatusChanged();
}

void FocusBridge::loadChromeExtensions() {
    QWebEngineProfile *profile = QWebEngineProfile::defaultProfile();
    if (!profile) return;
    QWebEngineExtensionManager *extMgr = profile->extensionManager();
    if (!extMgr) return;

    QStringList searchRoots;
    searchRoots << QDir::homePath() + "/.config/google-chrome/Default/Extensions"
                << QDir::homePath() + "/.config/chromium/Default/Extensions"
                << QDir::homePath() + "/.config/focus/extensions";

    for (const QString &root : searchRoots) {
        QDir dir(root);
        if (!dir.exists()) continue;
        QStringList idDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &idDirName : idDirs) {
            QDir idDir(dir.filePath(idDirName));
            QStringList versionDirs = idDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QString &ver : versionDirs) {
                QString extPath = idDir.filePath(ver);
                if (QFile::exists(extPath + "/manifest.json")) {
                    extMgr->loadExtension(extPath);
                }
            }
        }
    }
    emit extensionsChanged();
}

void FocusBridge::loadExtensionFromPath(const QString &path) {
    QWebEngineProfile *profile = QWebEngineProfile::defaultProfile();
    if (!profile) return;
    QWebEngineExtensionManager *extMgr = profile->extensionManager();
    if (!extMgr) return;
    if (QFile::exists(path + "/manifest.json")) {
        extMgr->loadExtension(path);
        emit extensionsChanged();
    }
}

QString FocusBridge::getLoadedExtensionsJson() const {
    QWebEngineProfile *profile = QWebEngineProfile::defaultProfile();
    if (!profile) return "[]";
    QWebEngineExtensionManager *extMgr = profile->extensionManager();
    if (!extMgr) return "[]";

    QJsonArray arr;
    for (const QWebEngineExtensionInfo &ext : extMgr->extensions()) {
        QJsonObject obj;
        obj["id"] = ext.id();
        obj["name"] = ext.name();
        obj["description"] = ext.description();
        obj["path"] = ext.path();
        obj["isEnabled"] = ext.isEnabled();
        obj["isLoaded"] = ext.isLoaded();
        arr.append(obj);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QString FocusBridge::queryBitwardenLogins(const QString &url) {
    if (url.isEmpty() || url == "about:blank") return "[]";

    QUrl parsed(url.startsWith("http") ? url : ("https://" + url));
    QString domain = parsed.host();

    QJsonArray resultArr;

    if (!m_bwSession.isEmpty() && QFile::exists("/usr/bin/bw")) {
        QProcess proc;
        proc.start("/usr/bin/bw", QStringList() << "list" << "items" << "--url" << url << "--session" << m_bwSession);
        if (proc.waitForFinished(3000) && proc.exitCode() == 0) {
            QByteArray out = proc.readAllStandardOutput().trimmed();
            QJsonDocument doc = QJsonDocument::fromJson(out);
            if (doc.isArray()) {
                for (const QJsonValue &v : doc.array()) {
                    QJsonObject item = v.toObject();
                    QJsonObject login = item.value("login").toObject();
                    QString user = login.value("username").toString();
                    QString pass = login.value("password").toString();
                    if (!user.isEmpty() || !pass.isEmpty()) {
                        QJsonObject cred;
                        cred["source"] = "bitwarden";
                        cred["name"] = item.value("name").toString(domain);
                        cred["username"] = user;
                        cred["password"] = pass;
                        resultArr.append(cred);
                    }
                }
            }
        }
    }

    // Fallback or complement with local passwords if domain matches
    QString localPath = QDir::homePath() + "/.config/focus/passwords.json";
    QFile localFile(localPath);
    if (localFile.open(QIODevice::ReadOnly)) {
        QJsonDocument localDoc = QJsonDocument::fromJson(localFile.readAll());
        localFile.close();
        if (localDoc.isArray()) {
            for (const QJsonValue &v : localDoc.array()) {
                QJsonObject item = v.toObject();
                QString d = item.value("domain").toString();
                QString u = item.value("url").toString();
                if ((!domain.isEmpty() && (d.contains(domain, Qt::CaseInsensitive) || domain.contains(d, Qt::CaseInsensitive))) ||
                    (!u.isEmpty() && url.contains(u, Qt::CaseInsensitive))) {
                    QJsonObject cred;
                    cred["source"] = "local";
                    cred["name"] = d.isEmpty() ? domain : d;
                    cred["username"] = item.value("username").toString();
                    cred["password"] = item.value("password").toString();
                    resultArr.append(cred);
                }
            }
        }
    }

    return QString::fromUtf8(QJsonDocument(resultArr).toJson(QJsonDocument::Compact));
}

QString FocusBridge::saveBitwardenCredential(const QString &url, const QString &username, const QString &password) {
    if (url.isEmpty() || username.isEmpty() || password.isEmpty()) {
        return "Dados incompletos para salvar.";
    }

    // Always also persist to local vault for immediate offline availability
    saveCredential(url, username, password);

    if (m_bwSession.isEmpty() || !QFile::exists("/usr/bin/bw")) {
        return "ok"; // Saved locally
    }

    QUrl parsed(url.startsWith("http") ? url : ("https://" + url));
    QString domain = parsed.host();
    if (domain.isEmpty()) domain = url;

    QJsonObject uriObj;
    uriObj["uri"] = url;
    uriObj["match"] = QJsonValue::Null;
    QJsonArray urisArr;
    urisArr.append(uriObj);

    QJsonObject loginObj;
    loginObj["username"] = username;
    loginObj["password"] = password;
    loginObj["uris"] = urisArr;

    QJsonObject itemObj;
    itemObj["type"] = 1; // 1 = Login
    itemObj["name"] = domain;
    itemObj["notes"] = "Salvo via Focus Browser";
    itemObj["favorite"] = false;
    itemObj["fields"] = QJsonArray();
    itemObj["login"] = loginObj;

    QJsonDocument doc(itemObj);
    QByteArray base64Json = doc.toJson(QJsonDocument::Compact).toBase64();

    QProcess proc;
    proc.start("/usr/bin/bw", QStringList() << "create" << "item" << QString::fromUtf8(base64Json) << "--session" << m_bwSession);
    if (!proc.waitForFinished(6000)) {
        return "Tempo limite ao salvar no cofre Bitwarden.";
    }

    if (proc.exitCode() == 0) {
        // Sync asynchronously so UI doesn't stall
        QProcess::startDetached("/usr/bin/bw", QStringList() << "sync" << "--session" << m_bwSession);
        return "ok";
    } else {
        QString err = QString::fromUtf8(proc.readAllStandardError()).trimmed();
        if (err.isEmpty()) err = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
        return err.isEmpty() ? "Erro ao salvar no Bitwarden." : err;
    }
}

#include <QKeyEvent>

class GlobalKeyFilter : public QObject {
public:
    explicit GlobalKeyFilter(FocusBridge *bridge, QObject *parent = nullptr)
        : QObject(parent), m_bridge(bridge) {}

protected:
    bool eventFilter(QObject *watched, QEvent *event) override {
        if (event->type() == QEvent::KeyPress) {
            auto *keyEvent = static_cast<QKeyEvent *>(event);
            int key = keyEvent->key();
            Qt::KeyboardModifiers mods = keyEvent->modifiers();

            // Alt+Space or Ctrl+Space: Always toggle launcher
            if (key == Qt::Key_Space && (mods & (Qt::AltModifier | Qt::ControlModifier))) {
                m_bridge->toggleLauncher();
                return true;
            }

            // Space alone: Opens launcher if launcher is currently closed
            if (key == Qt::Key_Space && (mods == Qt::NoModifier || mods == Qt::KeypadModifier)) {
                if (!m_bridge->launcherVisible() && !m_bridge->settingsVisible()) {
                    m_bridge->setLauncherVisible(true);
                    return true;
                }
            }

            // Escape: Close launcher if open
            if (key == Qt::Key_Escape && m_bridge->launcherVisible()) {
                m_bridge->setLauncherVisible(false);
                return true;
            }
        }
        return QObject::eventFilter(watched, event);
    }

private:
    FocusBridge *m_bridge;
};

extern "C" {

int focus_run_gui(
    int argc,
    char** argv,
    const char* qml_file_path,
    const char* initial_theme_json,
    const char* initial_config_json,
    const char* initial_bookmarks_json,
    const char* initial_history_json,
    RustCallbacks callbacks
) {
    // 1. Initialize QtWebEngine before QGuiApplication
    qputenv("QT_ENABLE_HIGHDPI_SCALING", "1");
    qputenv("QML_ENABLE_DISK_CACHE", "1");
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--enable-extensions --enable-features=ExtensionManifestV3");
    QtWebEngineQuick::initialize();

    // 2. Initialize QGuiApplication
    QGuiApplication app(argc, argv);
    app.setApplicationName("Focus");
    app.setOrganizationName("Omarchy");
    app.setOrganizationDomain("omarchy.org");

    QFont appFont("Inter");
    appFont.setStyleHint(QFont::SansSerif);
    app.setFont(appFont);

    // 3. Configure WebEngine default profile for persistent cookies, logins, and cache
    QString dataPath = QDir::homePath() + "/.local/share/focus";
    QDir().mkpath(dataPath + "/storage");
    QDir().mkpath(dataPath + "/cache");

    QWebEngineProfile *profile = QWebEngineProfile::defaultProfile();
    profile->setPersistentStoragePath(dataPath + "/storage");
    profile->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);
    profile->setCachePath(dataPath + "/cache");
    profile->setHttpCacheType(QWebEngineProfile::DiskHttpCache);

    // Initial Accept-Language (defaults to English "en-US,en;q=0.9")
    if (initial_config_json) {
        QJsonDocument cfgDoc = QJsonDocument::fromJson(QByteArray(initial_config_json));
        if (cfgDoc.isObject()) {
            QString lang = cfgDoc.object().value("language").toString("en-US");
            profile->setHttpAcceptLanguage(lang);
        }
    } else {
        profile->setHttpAcceptLanguage("en-US");
    }

    QWebEngineSettings *settings = profile->settings();
    settings->setAttribute(QWebEngineSettings::PluginsEnabled, true);
    settings->setAttribute(QWebEngineSettings::FullScreenSupportEnabled, true);
    settings->setAttribute(QWebEngineSettings::JavascriptCanAccessClipboard, true);
    settings->setAttribute(QWebEngineSettings::LocalStorageEnabled, true);
    settings->setAttribute(QWebEngineSettings::ScrollAnimatorEnabled, true);
    settings->setAttribute(QWebEngineSettings::WebGLEnabled, true);
    settings->setAttribute(QWebEngineSettings::Accelerated2dCanvasEnabled, true);

    // 4. Set up Bridge instance and initial data
    FocusBridge *bridge = FocusBridge::instance();
    bridge->setCallbacks(callbacks);
    bridge->initThemeWatcher();
    bridge->loadChromeExtensions();

    // Global Key Filter: intercept Space/Alt+Space across entire app/WebEngine
    GlobalKeyFilter *keyFilter = new GlobalKeyFilter(bridge, &app);
    app.installEventFilter(keyFilter);

    if (initial_theme_json) {
        bridge->setThemeJson(QString::fromUtf8(initial_theme_json));
    }
    if (initial_config_json) {
        bridge->setConfigJson(QString::fromUtf8(initial_config_json));
    }
    if (initial_bookmarks_json) {
        bridge->setBookmarksJson(QString::fromUtf8(initial_bookmarks_json));
    }
    if (initial_history_json) {
        bridge->setHistoryJson(QString::fromUtf8(initial_history_json));
    }

    // 5. Initialize QML Engine
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("bridge", bridge);

    QUrl url = QUrl::fromLocalFile(QString::fromUtf8(qml_file_path));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            std::cerr << "Focus: Failed to load QML root object from " << url.toString().toStdString() << std::endl;
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        std::cerr << "Focus: Engine root objects empty on startup!" << std::endl;
        return -1;
    }

    return app.exec();
}

} // extern "C"
