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
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
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
    for (int index = 0; index < 5; ++index) {
        QVERIFY(navigation->setProperty("currentIndex", index));
        window->update();
        QTest::qWait(80);
    }
    window->update();
    QTest::qWait(300);
    for (int index = 0; index < 5; ++index) {
        QVERIFY(navigation->setProperty("currentIndex", index));
        window->update();
        QTest::qWait(200);
        QCOMPARE(stack->property("currentIndex").toInt(), index);
        const QString screenshotDirectory = QStringLiteral(FITTRACK_SCREENSHOT_DIR);
        QVERIFY(QDir().mkpath(screenshotDirectory));
        const QStringList names{QStringLiteral("home"), QStringLiteral("plans"),
                                QStringLiteral("training"), QStringLiteral("exercises"),
                                QStringLiteral("insights")};
        QVERIFY(window->grabWindow().save(
            QDir(screenshotDirectory).filePath(names.at(index) + QStringLiteral(".png"))));
    }

    QVERIFY(workoutController.startSuggestedDay());
    restTimer.start(180);
    QVERIFY(navigation->setProperty("currentIndex", 2));
    window->update();
    QTest::qWait(300);
    QVERIFY(window->grabWindow().save(
        QDir(QStringLiteral(FITTRACK_SCREENSHOT_DIR))
            .filePath(QStringLiteral("training-active.png"))));
    restTimer.reset();

    QObject *insightsTabs = root->findChild<QObject *>(QStringLiteral("insightsTabs"));
    QVERIFY(insightsTabs);
    QVERIFY(navigation->setProperty("currentIndex", 4));
    const QList<QPair<int, QString>> secondaryPages{
        {2, QStringLiteral("cardio")},
        {3, QStringLiteral("management")},
    };
    for (const auto &[index, name] : secondaryPages) {
        QVERIFY(insightsTabs->setProperty("currentIndex", index));
        window->update();
        QTest::qWait(200);
        QVERIFY(window->grabWindow().save(
            QDir(QStringLiteral(FITTRACK_SCREENSHOT_DIR)).filePath(name + QStringLiteral(".png"))));
    }
}

int main(int argc, char **argv)
{
    if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "offscreen");
    if (!qEnvironmentVariableIsSet("QSG_RHI_BACKEND")) qputenv("QSG_RHI_BACKEND", "software");
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Material"));
    QmlNavigationTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_qmlnavigation.moc"
