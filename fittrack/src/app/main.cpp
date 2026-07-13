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
#ifndef Q_OS_ANDROID
#include "timer/timeralertplayer.h"
#endif
#include "training/workoutsessioncontroller.h"

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QResource>
#include <QStandardPaths>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

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

qreal platformFontScale()
{
    bool overrideOk = false;
    const qreal overrideScale = qEnvironmentVariable("FITTRACK_FONT_SCALE").toDouble(&overrideOk);
    if (overrideOk) {
        return qBound<qreal>(0.85, overrideScale, 2.0);
    }

#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return 1.0;
    }
    const QJniObject resources = context.callObjectMethod(
        "getResources", "()Landroid/content/res/Resources;");
    if (!resources.isValid()) {
        return 1.0;
    }
    const QJniObject configuration = resources.callObjectMethod(
        "getConfiguration", "()Landroid/content/res/Configuration;");
    if (configuration.isValid()) {
        return qBound<qreal>(0.85,
                             static_cast<qreal>(configuration.getField<jfloat>("fontScale")),
                             2.0);
    }
#endif
    return 1.0;
}

} // namespace

int main(int argc, char *argv[])
{
    Q_INIT_RESOURCE(action_images);
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("FitTrack"));
    QGuiApplication::setOrganizationName(QStringLiteral("FitTrack"));
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
    fittrack::ExerciseListModel exerciseModel(
        databaseManager.database(), exerciseDocuments, false);
    fittrack::ExerciseListModel planExerciseModel(
        databaseManager.database(), exerciseDocuments, false);
    fittrack::RestTimerController restTimer;
#ifndef Q_OS_ANDROID
    fittrack::TimerAlertPlayer timerAlert;
#endif
    fittrack::WorkoutSessionController workoutController(databaseManager.database());
    fittrack::WorkoutHistoryController workoutHistory(databaseManager.database());
    fittrack::AnalyticsDashboardController analyticsDashboard(databaseManager.database());
    fittrack::PlanManagementController planManagement(databaseManager.database());
    fittrack::CardioController cardioController(databaseManager.database());
    fittrack::GymManagementController gymManagement(databaseManager.database());
    fittrack::BackupService backupService(databaseManager.database());
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
    QObject::connect(
        &exerciseModel, &fittrack::ExerciseListModel::catalogChanged,
        &planExerciseModel, &fittrack::ExerciseListModel::reload);
    QObject::connect(
        &workoutController, &fittrack::WorkoutSessionController::planDaysChanged,
        &planManagement, &fittrack::PlanManagementController::reload);
    QObject::connect(
        &gymManagement, &fittrack::GymManagementController::catalogChanged,
        &workoutController, &fittrack::WorkoutSessionController::reloadGymData);
    QObject::connect(&backupService, &fittrack::BackupService::restored, [&] {
        restTimer.reset();
        exerciseModel.reload();
        planExerciseModel.reload();
        planManagement.reload();
        workoutController.reloadAfterRestore();
        workoutHistory.reload();
        analyticsDashboard.reload();
        cardioController.reload();
        gymManagement.reload();
    });
    QObject::connect(
        &workoutController,
        &fittrack::WorkoutSessionController::workoutFinished,
        &analyticsDashboard,
        &fittrack::AnalyticsDashboardController::reload);
#ifndef Q_OS_ANDROID
    QObject::connect(
        &restTimer, &fittrack::RestTimerController::finished,
        &timerAlert, &fittrack::TimerAlertPlayer::play);
#endif
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
    if (!engine.rootObjects().isEmpty()) {
        engine.rootObjects().constFirst()->setProperty("fontScale", platformFontScale());
    }
    QObject::connect(
        &app, &QGuiApplication::applicationStateChanged, &engine,
        [&engine](Qt::ApplicationState state) {
            if (state == Qt::ApplicationActive && !engine.rootObjects().isEmpty()) {
                engine.rootObjects().constFirst()->setProperty("fontScale", platformFontScale());
            }
        });

    return app.exec();
}
