#include "analytics/analyticsdashboardcontroller.h"
#include "exercises/exerciselistmodel.h"
#include "history/workouthistorycontroller.h"
#include "plans/planmanagementcontroller.h"
#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"
#include "storage/planseedimporter.h"
#include "timer/resttimercontroller.h"
#include "timer/timeralertplayer.h"
#include "training/workoutsessioncontroller.h"

#include <QDir>
#include <QFile>
#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>

namespace {

QByteArray readResource(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray{};
}

bool initializeDatabase(fittrack::DatabaseManager &databaseManager)
{
    const QString dataDirectory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (!QDir().mkpath(dataDirectory)) {
        qCritical() << "无法创建应用数据目录" << dataDirectory;
        return false;
    }

    QString error;
    if (!databaseManager.initialize(dataDirectory + QStringLiteral("/fittrack.sqlite"), &error)) {
        qCritical() << "数据库初始化失败" << error;
        return false;
    }

    const QList<QByteArray> exerciseDocuments{
        readResource(QStringLiteral(":/data/exercises-push.json")),
        readResource(QStringLiteral(":/data/exercises-pull.json")),
        readResource(QStringLiteral(":/data/exercises-legs.json")),
    };
    if (!fittrack::ExerciseSeedImporter::importDocuments(
            databaseManager.database(), exerciseDocuments, &error)) {
        qCritical() << "动作数据导入失败" << error;
        return false;
    }

    if (!fittrack::PlanSeedImporter::importDocument(
            databaseManager.database(),
            readResource(QStringLiteral(":/data/tan-three-day-split.json")),
            &error)) {
        qCritical() << "训练计划导入失败" << error;
        return false;
    }
    return true;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("FitTrack"));
    QGuiApplication::setOrganizationName(QStringLiteral("FitTrack"));
#ifdef Q_OS_WIN
    QGuiApplication::setFont(QFont(QStringLiteral("Microsoft YaHei UI")));
#endif
    QQuickStyle::setStyle(QStringLiteral("Material"));

    fittrack::DatabaseManager databaseManager;
    if (!initializeDatabase(databaseManager)) {
        return -1;
    }

    QQmlApplicationEngine engine;
    const QList<QByteArray> exerciseDocuments{
        readResource(QStringLiteral(":/data/exercises-push.json")),
        readResource(QStringLiteral(":/data/exercises-pull.json")),
        readResource(QStringLiteral(":/data/exercises-legs.json")),
    };
    fittrack::ExerciseListModel exerciseModel(databaseManager.database(), exerciseDocuments);
    fittrack::ExerciseListModel planExerciseModel(databaseManager.database(), exerciseDocuments);
    fittrack::RestTimerController restTimer;
    fittrack::TimerAlertPlayer timerAlert;
    fittrack::WorkoutSessionController workoutController(databaseManager.database());
    fittrack::WorkoutHistoryController workoutHistory(databaseManager.database());
    fittrack::AnalyticsDashboardController analyticsDashboard(databaseManager.database());
    fittrack::PlanManagementController planManagement(databaseManager.database());
    engine.rootContext()->setContextProperty(QStringLiteral("exerciseModel"), &exerciseModel);
    engine.rootContext()->setContextProperty(QStringLiteral("planExerciseModel"), &planExerciseModel);
    engine.rootContext()->setContextProperty(QStringLiteral("restTimer"), &restTimer);
    engine.rootContext()->setContextProperty(QStringLiteral("workoutController"), &workoutController);
    engine.rootContext()->setContextProperty(QStringLiteral("workoutHistory"), &workoutHistory);
    engine.rootContext()->setContextProperty(QStringLiteral("analyticsDashboard"), &analyticsDashboard);
    engine.rootContext()->setContextProperty(QStringLiteral("planManagement"), &planManagement);
    QObject::connect(
        &exerciseModel, &QAbstractItemModel::modelReset,
        &planExerciseModel, &fittrack::ExerciseListModel::reload);
    QObject::connect(
        &workoutController, &fittrack::WorkoutSessionController::planDaysChanged,
        &planManagement, &fittrack::PlanManagementController::reload);
    QObject::connect(
        &workoutController,
        &fittrack::WorkoutSessionController::workoutFinished,
        &workoutHistory,
        [&workoutHistory, &analyticsDashboard](const QString &sessionId) {
            workoutHistory.reload();
            workoutHistory.selectSession(sessionId);
            analyticsDashboard.reload();
        });
    QObject::connect(
        &restTimer, &fittrack::RestTimerController::finished,
        &timerAlert, &fittrack::TimerAlertPlayer::play);
    QObject::connect(
        &app, &QGuiApplication::applicationStateChanged,
        &restTimer, [&restTimer](Qt::ApplicationState state) {
            if (state == Qt::ApplicationActive) restTimer.synchronize();
        });
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [] { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("FitTrack"), QStringLiteral("Main"));

    return app.exec();
}
