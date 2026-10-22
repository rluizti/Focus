#pragma once

#include <QObject>
#include <QString>
#include <functional>

typedef void (*RustConfigSavedFn)(const char* json);
typedef void (*RustChromeSyncFn)(char** out_bookmarks, char** out_history);
typedef void (*RustSwitchEngineFn)(const char* engine, const char* url);
typedef void (*RustFreeStringFn)(char* s);

struct RustCallbacks {
    RustConfigSavedFn onConfigSaved;
    RustChromeSyncFn onChromeSync;
    RustSwitchEngineFn onSwitchEngine;
    RustFreeStringFn freeString;
};

class OmaBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString themeJson READ themeJson WRITE setThemeJson NOTIFY themeJsonChanged)
    Q_PROPERTY(QString configJson READ configJson WRITE setConfigJson NOTIFY configJsonChanged)
    Q_PROPERTY(QString bookmarksJson READ bookmarksJson WRITE setBookmarksJson NOTIFY bookmarksJsonChanged)
    Q_PROPERTY(QString historyJson READ historyJson WRITE setHistoryJson NOTIFY historyJsonChanged)
    Q_PROPERTY(QString currentEngine READ currentEngine WRITE setCurrentEngine NOTIFY currentEngineChanged)
    Q_PROPERTY(QString currentUrl READ currentUrl WRITE setCurrentUrl NOTIFY currentUrlChanged)
    Q_PROPERTY(QString pageTitle READ pageTitle WRITE setPageTitle NOTIFY pageTitleChanged)
    Q_PROPERTY(bool isLoading READ isLoading WRITE setIsLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(qreal loadProgress READ loadProgress WRITE setLoadProgress NOTIFY loadProgressChanged)
    Q_PROPERTY(bool launcherVisible READ launcherVisible WRITE setLauncherVisible NOTIFY launcherVisibleChanged)
    Q_PROPERTY(bool settingsVisible READ settingsVisible WRITE setSettingsVisible NOTIFY settingsVisibleChanged)
    Q_PROPERTY(QString passwordsJson READ passwordsJson NOTIFY passwordsJsonChanged)

public:
    explicit OmaBridge(QObject *parent = nullptr);

    static OmaBridge* instance();

    void setCallbacks(RustCallbacks callbacks);

    QString themeJson() const { return m_themeJson; }
    void setThemeJson(const QString &val);

    QString configJson() const { return m_configJson; }
    void setConfigJson(const QString &val);

    QString bookmarksJson() const { return m_bookmarksJson; }
    void setBookmarksJson(const QString &val);

    QString historyJson() const { return m_historyJson; }
    void setHistoryJson(const QString &val);

    QString currentEngine() const { return m_currentEngine; }
    void setCurrentEngine(const QString &val);

    QString currentUrl() const { return m_currentUrl; }
    void setCurrentUrl(const QString &val);

    QString pageTitle() const { return m_pageTitle; }
    void setPageTitle(const QString &val);

    bool isLoading() const { return m_isLoading; }
    void setIsLoading(bool val);

    qreal loadProgress() const { return m_loadProgress; }
    void setLoadProgress(qreal val);

    bool launcherVisible() const { return m_launcherVisible; }
    void setLauncherVisible(bool val);

    bool settingsVisible() const { return m_settingsVisible; }
    void setSettingsVisible(bool val);

    QString passwordsJson() const;
    Q_INVOKABLE void saveCredential(const QString &url, const QString &username, const QString &password);
    Q_INVOKABLE void deleteCredential(const QString &id);
    Q_INVOKABLE int importPasswordsFromCsv(const QString &csvPath);

    Q_INVOKABLE void saveConfig(const QString &json);
    Q_INVOKABLE void syncChrome();
    Q_INVOKABLE void switchEngine(const QString &engine, const QString &url = QString());
    Q_INVOKABLE void launchFirefox(const QString &url);
    Q_INVOKABLE void toggleLauncher();
    Q_INVOKABLE void toggleSettings();
    Q_INVOKABLE void closeBrowser();

    Q_INVOKABLE bool isBitwardenInstalled() const;
    Q_INVOKABLE void openBitwarden();
    Q_INVOKABLE QString getBitwardenStatus();

    void initThemeWatcher();
    void reloadThemeFromDisk();

signals:
    void themeJsonChanged();
    void configJsonChanged();
    void bookmarksJsonChanged();
    void historyJsonChanged();
    void passwordsJsonChanged();
    void currentEngineChanged();
    void currentUrlChanged();
    void pageTitleChanged();
    void isLoadingChanged();
    void loadProgressChanged();
    void launcherVisibleChanged();
    void settingsVisibleChanged();

    void navigateRequested(const QString &url);
    void newTabRequested(const QString &url);

private slots:
    void onThemeFilesChanged();
    void checkThemeUpdates();

private:
    static OmaBridge *s_instance;
    RustCallbacks m_callbacks;

    class QFileSystemWatcher *m_themeWatcher = nullptr;
    class QTimer *m_themeTimer = nullptr;
    QString m_lastThemeName;

    QString m_themeJson;
    QString m_configJson;
    QString m_bookmarksJson;
    QString m_historyJson;
    QString m_currentEngine = "chromium";
    QString m_currentUrl = "";
    QString m_pageTitle = "Focus";
    bool m_isLoading = false;
    qreal m_loadProgress = 0.0;
    bool m_launcherVisible = true;
    bool m_settingsVisible = false;
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
    );
}
