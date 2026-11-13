#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "../StyleTokensBackend.h"

class StyleTokensCheck : public QObject {
    Q_OBJECT

private slots:
    void overridesTokens();
    void invalidTokenKeepsDefault();
    void missingFileKeepsDefault();
};

void StyleTokensCheck::overridesTokens()
{
    QTemporaryDir state;
    qputenv("XDG_STATE_HOME", state.path().toUtf8());
    QTemporaryDir dir;
    QFile file(dir.filePath("tide-colors.json"));
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(R"({"panel":"#123456","textPrimary":"#ff0000"})");
    file.close();

    StyleTokensBackend tokens;
    QSignalSpy spy(&tokens, &StyleTokensBackend::changed);
    QVERIFY(tokens.loadFromPath(file.fileName()));

    QCOMPARE(tokens.panel(), QColor("#123456"));
    QCOMPARE(tokens.textPrimary(), QColor("#ff0000"));
    QCOMPARE(spy.count(), 1);
}

void StyleTokensCheck::invalidTokenKeepsDefault()
{
    QTemporaryDir state;
    qputenv("XDG_STATE_HOME", state.path().toUtf8());
    QTemporaryDir dir;
    QFile file(dir.filePath("tide-colors.json"));
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(R"({"panel":"not-a-color"})");
    file.close();

    StyleTokensBackend tokens;
    QVERIFY(tokens.loadFromPath(file.fileName()));
    QCOMPARE(tokens.panel(), QColor("#202125"));
}

void StyleTokensCheck::missingFileKeepsDefault()
{
    QTemporaryDir state;
    qputenv("XDG_STATE_HOME", state.path().toUtf8());
    StyleTokensBackend tokens;
    QVERIFY(!tokens.loadFromPath("/nonexistent/tide-colors.json"));
    QCOMPARE(tokens.panel(), QColor("#202125"));
}

QTEST_MAIN(StyleTokensCheck)
#include "style_tokens_check.moc"
