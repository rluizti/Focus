#include "bridge.h"

#include <QGuiApplication>
#include <QFont>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
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

OmaBridge *OmaBridge::s_instance = nullptr;

OmaBridge::OmaBridge(QObject *parent) : QObject(parent) {
    s_instance = this;
    m_callbacks = {nullptr, nullptr, nullptr, nullptr};
}

OmaBridge* OmaBridge::instance() {
    if (!s_instance) {
        s_instance = new OmaBridge();
    }
    return s_instance;
}

void OmaBridge::setCallbacks(RustCallbacks callbacks) {
    m_callbacks = callbacks;
}

void OmaBridge::setThemeJson(const QString &val) {
    if (m_themeJson != val) {
        m_themeJson = val;
        emit themeJsonChanged();
    }
}

void OmaBridge::setConfigJson(const QString &val) {
    if (m_configJson != val) {
        m_configJson = val;
        emit configJsonChanged();
    }
}

void OmaBridge::setBookmarksJson(const QString &val) {
    if (m_bookmarksJson != val) {
        m_bookmarksJson = val;
        emit bookmarksJsonChanged();
    }
}

void OmaBridge::setHistoryJson(const QString &val) {
    if (m_historyJson != val) {
        m_historyJson = val;
        emit historyJsonChanged();
    }
}

void OmaBridge::setCurrentEngine(const QString &val) {
    if (m_currentEngine != val) {
        m_currentEngine = val;
        emit currentEngineChanged();
    }
}

void OmaBridge::setCurrentUrl(const QString &val) {
    if (m_currentUrl != val) {
        m_currentUrl = val;
        emit currentUrlChanged();
    }
}

void OmaBridge::setPageTitle(const QString &val) {
    if (m_pageTitle != val) {
        m_pageTitle = val;
        emit pageTitleChanged();
    }
}

void OmaBridge::setIsLoading(bool val) {
    if (m_isLoading != val) {
        m_isLoading = val;
        emit isLoadingChanged();
    }
}

void OmaBridge::setLoadProgress(qreal val) {
    if (m_loadProgress != val) {
        m_loadProgress = val;
        emit loadProgressChanged();
    }
}

void OmaBridge::setLauncherVisible(bool val) {
    if (m_launcherVisible != val) {
        m_launcherVisible = val;
        emit launcherVisibleChanged();
    }
}

void OmaBridge::setSettingsVisible(bool val) {
    if (m_settingsVisible != val) {
        m_settingsVisible = val;
        emit settingsVisibleChanged();
    }
}

void OmaBridge::saveConfig(const QString &json) {
    m_configJson = json;
    emit configJsonChanged();
    if (m_callbacks.onConfigSaved) {
        QByteArray utf8 = json.toUtf8();
        m_callbacks.onConfigSaved(utf8.constData());
    }
}

QString OmaBridge::passwordsJson() const {
    QString path = QDir::homePath() + "/.config/focus/passwords.json";
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        return QString::fromUtf8(file.readAll());
    }
    return "[]";
}

void OmaBridge::saveCredential(const QString &url, const QString &username, const QString &password) {
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

void OmaBridge::deleteCredential(const QString &id) {
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

int OmaBridge::importPasswordsFromCsv(const QString &csvPath) {
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

void OmaBridge::syncChrome() {
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

void OmaBridge::switchEngine(const QString &engine, const QString &url) {
    setCurrentEngine(engine);
    if (m_callbacks.onSwitchEngine) {
        QByteArray eng = engine.toUtf8();
        QByteArray u = url.toUtf8();
        m_callbacks.onSwitchEngine(eng.constData(), u.constData());
    }
}

void OmaBridge::launchFirefox(const QString &url) {
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

void OmaBridge::initThemeWatcher() {
    m_themeWatcher = new QFileSystemWatcher(this);
    QString stateDir = QDir::homePath() + "/.local/state/omarchy/current";
    QString themeNamePath = stateDir + "/theme.name";
    QString colorsPath = stateDir + "/theme/colors.toml";

    if (QFile::exists(themeNamePath)) m_themeWatcher->addPath(themeNamePath);
    if (QFile::exists(colorsPath)) m_themeWatcher->addPath(colorsPath);
    if (QDir(stateDir).exists()) m_themeWatcher->addPath(stateDir);

    connect(m_themeWatcher, &QFileSystemWatcher::fileChanged, this, &OmaBridge::onThemeFilesChanged);
    connect(m_themeWatcher, &QFileSystemWatcher::directoryChanged, this, &OmaBridge::onThemeFilesChanged);

    m_themeTimer = new QTimer(this);
    connect(m_themeTimer, &QTimer::timeout, this, &OmaBridge::checkThemeUpdates);
    m_themeTimer->start(600); // 600ms polling guarantees detection even with atomic symlink swaps
}

void OmaBridge::onThemeFilesChanged() {
    reloadThemeFromDisk();
}

void OmaBridge::checkThemeUpdates() {
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

void OmaBridge::reloadThemeFromDisk() {
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
    obj["font_family"] = "omarchy, Inter, sans-serif";
    obj["corner_radius"] = rounding; // Follows Omarchy theme rounding (0 for sharp, 6/8/12 for rounded)

    QJsonDocument doc(obj);
    QString jsonStr = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
    setThemeJson(jsonStr);
}

void OmaBridge::toggleLauncher() {
    setLauncherVisible(!m_launcherVisible);
}

void OmaBridge::toggleSettings() {
    setSettingsVisible(!m_settingsVisible);
}

void OmaBridge::closeBrowser() {
    QGuiApplication::quit();
}

bool OmaBridge::isBitwardenInstalled() const {
    return QFile::exists("/usr/bin/bitwarden-desktop") || QFile::exists("/usr/bin/bitwarden") || QFile::exists("/usr/bin/bw");
}

void OmaBridge::openBitwarden() {
    if (QFile::exists("/usr/bin/bitwarden-desktop")) {
        QProcess::startDetached("/usr/bin/bitwarden-desktop", QStringList());
    } else if (QFile::exists("/usr/bin/bitwarden")) {
        QProcess::startDetached("/usr/bin/bitwarden", QStringList());
    } else if (QFile::exists("/usr/bin/bw")) {
        QProcess::startDetached("xdg-open", QStringList() << "https://vault.bitwarden.com");
    }
}

QString OmaBridge::getBitwardenStatus() {
    if (!QFile::exists("/usr/bin/bw")) {
        return "not_installed";
    }
    QProcess proc;
    proc.start("/usr/bin/bw", QStringList() << "status");
    if (proc.waitForFinished(1200)) {
        return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    }
    return "timeout";
}

#include <QKeyEvent>

class GlobalKeyFilter : public QObject {
public:
    explicit GlobalKeyFilter(OmaBridge *bridge, QObject *parent = nullptr)
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
    OmaBridge *m_bridge;
};

extern "C" {

int oma_run_gui(
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
    QtWebEngineQuick::initialize();

    // 2. Initialize QGuiApplication
    QGuiApplication app(argc, argv);
    app.setApplicationName("Focus");
    app.setOrganizationName("Omarchy");
    app.setOrganizationDomain("omarchy.org");

    QFont appFont("omarchy");
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

    QWebEngineSettings *settings = profile->settings();
    settings->setAttribute(QWebEngineSettings::PluginsEnabled, true);
    settings->setAttribute(QWebEngineSettings::FullScreenSupportEnabled, true);
    settings->setAttribute(QWebEngineSettings::JavascriptCanAccessClipboard, true);
    settings->setAttribute(QWebEngineSettings::LocalStorageEnabled, true);
    settings->setAttribute(QWebEngineSettings::ScrollAnimatorEnabled, true);
    settings->setAttribute(QWebEngineSettings::WebGLEnabled, true);
    settings->setAttribute(QWebEngineSettings::Accelerated2dCanvasEnabled, true);

    // 4. Set up Bridge instance and initial data
    OmaBridge *bridge = OmaBridge::instance();
    bridge->setCallbacks(callbacks);
    bridge->initThemeWatcher();

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
            std::cerr << "OmaBrowser: Failed to load QML root object from " << url.toString().toStdString() << std::endl;
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        std::cerr << "OmaBrowser: Engine root objects empty on startup!" << std::endl;
        return -1;
    }

    return app.exec();
}

} // extern "C"
