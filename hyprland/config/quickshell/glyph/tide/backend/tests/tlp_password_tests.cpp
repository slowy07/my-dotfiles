#include "SystemServices.h"

#include <QFile>
#include <QJSEngine>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#ifdef Q_OS_UNIX
#include <unistd.h>
#endif

namespace {
class EnvironmentGuard {
public:
    explicit EnvironmentGuard(const QByteArray &name)
        : name(name), value(qgetenv(name)), wasSet(qEnvironmentVariableIsSet(name.constData())) {}
    ~EnvironmentGuard() {
        if (wasSet) qputenv(name, value);
        else qunsetenv(name);
    }
private:
    QByteArray name;
    QByteArray value;
    bool wasSet;
};

bool writeFile(const QString &path, const QByteArray &data, bool executable = false) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size()) return false;
    file.close();
    return !executable || file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
}

QByteArray readFile(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

void passwordRows() {
    QTest::addColumn<QString>("password");
    QTest::newRow("plain") << QStringLiteral("test-password");
    QTest::newRow("internal-spaces") << QStringLiteral("test  password");
    QTest::newRow("leading-spaces") << QStringLiteral("  test-password");
    QTest::newRow("trailing-spaces") << QStringLiteral("test-password  ");
    QTest::newRow("both-ends") << QStringLiteral("  test password  ");
    QTest::newRow("tabs") << QStringLiteral("\t test\t password \t");
    QTest::newRow("only-whitespace") << QStringLiteral(" \t  ");
    QTest::newRow("unicode-and-shell-characters") << QString::fromUtf8("  päss '$HOME'; `test` \\\"  ");
}
}

class TlpPasswordTests : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() {
#ifdef Q_OS_UNIX
        if (::getuid() == 0) QSKIP("Root bypasses password authentication.");
#else
        QSKIP("TLP authentication is only available on Unix.");
#endif
    }
    void savedPassword_data() { passwordRows(); }
    void savedPassword() { QFETCH(QString, password); checkPassword(password, false); }
    void promptedPassword_data() { passwordRows(); }
    void promptedPassword() { QFETCH(QString, password); checkPassword(password, true); }
    void emptyPassword() { checkPassword(QString(), false); }

private:
    void checkPassword(const QString &password, bool prompt) {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString path = directory.path();
        EnvironmentGuard oldPath("PATH");
        EnvironmentGuard oldConfig("XDG_CONFIG_HOME");
        EnvironmentGuard oldInput("TIDE_TLP_TEST_INPUT");
        EnvironmentGuard oldArguments("TIDE_TLP_TEST_ARGUMENTS");
        EnvironmentGuard oldPrompt("TIDE_TLP_TEST_PROMPT");
        EnvironmentGuard oldPkexec("TIDE_TLP_TEST_PKEXEC");
        qputenv("PATH", path.toUtf8());
        qputenv("XDG_CONFIG_HOME", path.toUtf8());
        qputenv("TIDE_TLP_TEST_INPUT", (path + "/stdin").toUtf8());
        qputenv("TIDE_TLP_TEST_ARGUMENTS", (path + "/arguments").toUtf8());
        qputenv("TIDE_TLP_TEST_PROMPT", (path + "/prompt").toUtf8());
        qputenv("TIDE_TLP_TEST_PKEXEC", (path + "/pkexec-called").toUtf8());

        // Fake every privileged command: inspect stdin without authenticating or changing power settings.
        QVERIFY(writeFile(path + "/tlp", "#!/bin/sh\nexit 0\n", true));
        QVERIFY(writeFile(path + "/sudo",
            "#!/bin/sh\nprintf '%s\\0' \"$@\" > \"$TIDE_TLP_TEST_ARGUMENTS\"\n"
            "/bin/cat > \"$TIDE_TLP_TEST_INPUT\"\n", true));
        QVERIFY(writeFile(path + "/pkexec",
            "#!/bin/sh\nprintf called > \"$TIDE_TLP_TEST_PKEXEC\"\n", true));
        QVERIFY(writeFile(path + "/zenity",
            "#!/bin/sh\n/bin/cat \"$TIDE_TLP_TEST_PROMPT\"\n", true));
        QVERIFY(writeFile(path + "/prompt", password.toUtf8() + '\n'));

        SystemServices services;
        QQmlEngine::setObjectOwnership(&services, QQmlEngine::CppOwnership);
        QSignalSpy finished(&services, &SystemServices::tlpSetFinished);
        QJSEngine engine;
        if (prompt) {
            services.setPowerProfileMode(QStringLiteral("tlp"), QStringLiteral("balanced"), QString(), true);
        } else {
            // Exercise the real control-center function as well as the C++ process boundary.
            QFile source(QStringLiteral(CONTROL_CENTER_SOURCE));
            QVERIFY(source.open(QIODevice::ReadOnly));
            const QString qml = QString::fromUtf8(source.readAll());
            const qsizetype begin = qml.indexOf(QStringLiteral("    function selectBatteryMode("));
            const qsizetype end = qml.indexOf(QStringLiteral("    function finishBatteryModeApply("), begin);
            QVERIFY(begin >= 0 && end > begin);
            engine.globalObject().setProperty(QStringLiteral("SystemServices"), engine.newQObject(&services));
            engine.globalObject().setProperty(QStringLiteral("testPassword"), password);
            const auto initialized = engine.evaluate(QStringLiteral(R"JS(
                var batteryModeBusy = false, batteryModeSetterRunning = false;
                var batteryTlpChecked = true, batteryTlpAvailable = true, batteryModeAppliedIndex = 0;
                var controlCenter = {tlpControlsEnabled: true, powerDriver: "tlp"};
                var userConfig = {tlpPermissionMode: "password", tlpSudoPassword: testPassword};
                function queueBatteryModeStateRefresh() {}
                function batteryModeLabel() { return "Balanced"; }
                function batteryModeCommand() { return "balanced"; }
                function setBatteryModeVisualIndex() {}
                function trimString(value) { return value == null ? "" : String(value).trim(); }
            )JS") + qml.mid(begin, end - begin) + QStringLiteral("\nselectBatteryMode(1);"));
            QVERIFY2(!initialized.isError(), qPrintable(initialized.toString()));
        }
        QTRY_COMPARE_WITH_TIMEOUT(finished.count(), 1, 3000);
        QVERIFY(finished.first().first().toBool());
        if (password.isEmpty()) {
            QCOMPARE(readFile(path + "/pkexec-called"), QByteArray("called"));
            QVERIFY(!QFile::exists(path + "/stdin"));
        } else {
            QCOMPARE(readFile(path + "/stdin"), password.toUtf8() + '\n');
            QCOMPARE(readFile(path + "/arguments"), QByteArray("-S\0-p\0\0tlp\0balanced\0", 20));
            QVERIFY(!QFile::exists(path + "/pkexec-called"));
        }
    }
};

QTEST_GUILESS_MAIN(TlpPasswordTests)
#include "tlp_password_tests.moc"
