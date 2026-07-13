#include "analytics/analyticsdashboardcontroller.h"
#include "backup/backupservice.h"
#include "cardio/cardiocontroller.h"
#include "exercises/exerciselistmodel.h"
#include "gyms/gymmanagementcontroller.h"
#include "history/workouthistorycontroller.h"
#include "plans/planmanagementcontroller.h"
#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"
#include "storage/planseedimporter.h"
#include "timer/resttimercontroller.h"
#include "training/workoutsessioncontroller.h"

#include <QFile>
#include <QDir>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSize>
#include <QTest>

class QmlNavigationTest final : public QObject
{
    Q_OBJECT

private slots:
    void loadsAndSwitchesEveryPrimaryPage();
};

namespace {

QByteArray readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray{};
}

} // namespace

void QmlNavigationTest::loadsAndSwitchesEveryPrimaryPage()
{
    fittrack::DatabaseManager databaseManager;
    QString error;
    QVERIFY2(databaseManager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const QList<QByteArray> exerciseDocuments{
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-push.json")),
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-pull.json")),
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-legs.json")),
    };
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 databaseManager.database(), exerciseDocuments, &error), qPrintable(error));
    QVERIFY2(fittrack::PlanSeedImporter::importDocument(
                 databaseManager.database(),
                 readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/tan-three-day-split.json")),
                 &error), qPrintable(error));

    fittrack::ExerciseListModel exerciseModel(databaseManager.database(), exerciseDocuments);
    fittrack::ExerciseListModel planExerciseModel(databaseManager.database(), exerciseDocuments);
    fittrack::RestTimerController restTimer;
    fittrack::WorkoutSessionController workoutController(databaseManager.database());
    fittrack::WorkoutHistoryController workoutHistory(databaseManager.database());
    fittrack::AnalyticsDashboardController analyticsDashboard(databaseManager.database());
    fittrack::PlanManagementController planManagement(databaseManager.database());
    fittrack::CardioController cardioController(databaseManager.database());
    fittrack::GymManagementController gymManagement(databaseManager.database());
    fittrack::BackupService backupService(databaseManager.database());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("exerciseModel"), &exerciseModel);
    engine.rootContext()->setContextProperty(QStringLiteral("planExerciseModel"), &planExerciseModel);
    engine.rootContext()->setContextProperty(QStringLiteral("restTimer"), &restTimer);
    engine.rootContext()->setContextProperty(QStringLiteral("workoutController"), &workoutController);
    engine.rootContext()->setContextProperty(QStringLiteral("workoutHistory"), &workoutHistory);
    engine.rootContext()->setContextProperty(QStringLiteral("analyticsDashboard"), &analyticsDashboard);
    engine.rootContext()->setContextProperty(QStringLiteral("planManagement"), &planManagement);
    engine.rootContext()->setContextProperty(QStringLiteral("cardioController"), &cardioController);
    engine.rootContext()->setContextProperty(QStringLiteral("gymManagement"), &gymManagement);
    engine.rootContext()->setContextProperty(QStringLiteral("backupService"), &backupService);
    engine.load(QUrl::fromLocalFile(QStringLiteral(FITTRACK_SOURCE_DIR "/qml/Main.qml")));
    QCOMPARE(engine.rootObjects().size(), 1);
    QObject *root = engine.rootObjects().first();
    auto *window = qobject_cast<QQuickWindow *>(root);
    QVERIFY(window);
    QObject *navigation = root->findChild<QObject *>(QStringLiteral("navigation"));
    QObject *stack = root->findChild<QObject *>(QStringLiteral("mainStack"));
    QVERIFY(navigation);
    QVERIFY(stack);
    const QString screenshotDirectory = QStringLiteral(FITTRACK_SCREENSHOT_DIR);
    QVERIFY(QDir().mkpath(screenshotDirectory));
    const QList<QSize> viewports{
        QSize(360, 800), QSize(420, 920), QSize(480, 1056),
    };
    const auto capture = [&](const QString &name, const QSize &viewport) {
        window->setWidth(viewport.width());
        window->setHeight(viewport.height());
        window->update();
        QTest::qWait(180);
        if (stack->property("width").toReal() > window->width() + 0.5
            || navigation->property("width").toReal() > window->width() + 0.5) {
            return false;
        }
        const QImage image = window->grabWindow();
        const QString suffix = QStringLiteral("-%1x%2").arg(viewport.width()).arg(viewport.height());
        if (image.isNull()
            || !image.save(QDir(screenshotDirectory).filePath(name + suffix + QStringLiteral(".png")))) {
            return false;
        }
        return viewport.width() != 420
               || image.save(QDir(screenshotDirectory).filePath(name + QStringLiteral(".png")));
    };
    for (int index = 0; index < 5; ++index) {
        QVERIFY(navigation->setProperty("currentIndex", index));
        window->update();
        QTest::qWait(80);
    }
    window->update();
    QTest::qWait(300);
    const QStringList names{QStringLiteral("home"), QStringLiteral("plans"),
                            QStringLiteral("training"), QStringLiteral("exercises"),
                            QStringLiteral("insights")};
    for (const QSize &viewport : viewports) {
        for (int index = 0; index < 5; ++index) {
            QVERIFY(navigation->setProperty("currentIndex", index));
            window->update();
            QTest::qWait(100);
            QCOMPARE(stack->property("currentIndex").toInt(), index);
            QVERIFY(capture(names.at(index), viewport));
        }
    }

    QVERIFY(workoutController.startSuggestedDay());
    restTimer.start(180);
    QVERIFY(navigation->setProperty("currentIndex", 2));
    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("training-active"), viewport));
    restTimer.reset();

    QVERIFY(workoutController.completeSet(0, 0, 40.0, 10));
    restTimer.reset();
    QVERIFY(workoutController.finishWorkout());
    workoutHistory.reload();
    QVERIFY(!workoutHistory.sessions().isEmpty());
    QVERIFY(workoutHistory.selectSession(
        workoutHistory.sessions().first().toMap().value(QStringLiteral("id")).toString()));
    QObject *historyPage = root->findChild<QObject *>(QStringLiteral("historyPage"));
    QVERIFY(historyPage);
    QVERIFY(historyPage->setProperty("showDetails", true));

    QObject *insightsTabs = root->findChild<QObject *>(QStringLiteral("insightsTabs"));
    QVERIFY(insightsTabs);
    QVERIFY(navigation->setProperty("currentIndex", 4));
    const QList<QPair<int, QString>> secondaryPages{
        {1, QStringLiteral("history")},
        {2, QStringLiteral("cardio")},
        {3, QStringLiteral("management")},
    };
    for (const auto &[index, name] : secondaryPages) {
        QVERIFY(insightsTabs->setProperty("currentIndex", index));
        for (const QSize &viewport : viewports)
            QVERIFY(capture(name, viewport));
    }
}

int main(int argc, char **argv)
{
    if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "offscreen");
    if (!qEnvironmentVariableIsSet("QSG_RHI_BACKEND")) qputenv("QSG_RHI_BACKEND", "software");
    QGuiApplication app(argc, argv);
    const int fontId = QFontDatabase::addApplicationFont(
        QStringLiteral(FITTRACK_SOURCE_DIR "/resources/fonts/InterVariable.ttf"));
    const QStringList fontFamilies = QFontDatabase::applicationFontFamilies(fontId);
    if (!fontFamilies.isEmpty()) app.setFont(QFont(fontFamilies.constFirst()));
    QQuickStyle::setStyle(QStringLiteral("Material"));
    QmlNavigationTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_qmlnavigation.moc"
