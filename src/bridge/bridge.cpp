#include "bridge.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#include <QWebEngineProfile>
#include <QWebEngineSettings>
#include <QStandardPaths>
#include <QDir>
#include <QProcess>
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

void OmaBridge::toggleLauncher() {
    setLauncherVisible(!m_launcherVisible);
}

void OmaBridge::toggleSettings() {
    setSettingsVisible(!m_settingsVisible);
}

void OmaBridge::closeBrowser() {
    QGuiApplication::quit();
}

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
