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

#include <QAccessible>
#include <QFile>
#include <QDir>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QPointingDevice>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QResource>
#include <QSet>
#include <QSize>
#include <QSqlQuery>
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

bool isValidUtf8(const QByteArray &data)
{
    return !data.isEmpty() && QString::fromUtf8(data).toUtf8() == data;
}

QAccessibleInterface *findAccessibleByName(
    QAccessibleInterface *root, const QString &name,
    QAccessible::Role role = QAccessible::NoRole,
    QSet<QAccessibleInterface *> *visited = nullptr)
{
    if (!root || !root->isValid()) return nullptr;

    QSet<QAccessibleInterface *> localVisited;
    if (!visited) visited = &localVisited;
    if (visited->contains(root)) return nullptr;
    visited->insert(root);

    const QAccessible::State state = root->state();
    if (!state.invisible && root->text(QAccessible::Name) == name
        && (role == QAccessible::NoRole || root->role() == role)) {
        return root;
    }
    for (int index = 0; index < root->childCount(); ++index) {
        if (QAccessibleInterface *match = findAccessibleByName(
                root->child(index), name, role, visited)) {
            return match;
        }
    }
    return nullptr;
}

QRectF itemSceneRect(QAccessibleInterface *interface, QQuickWindow *window)
{
    if (interface) {
        if (auto *item = qobject_cast<QQuickItem *>(interface->object()))
            return item->mapRectToScene(item->boundingRect());
        const QRect globalRect = interface->rect();
        return QRectF(globalRect.translated(-window->position()));
    }
    return {};
}

bool isTouchTargetAtLeast(QAccessibleInterface *interface, QQuickWindow *window, qreal minimum)
{
    const QRectF rect = itemSceneRect(interface, window);
    return rect.width() >= minimum && rect.height() >= minimum;
}

bool touchTapAt(QQuickWindow *window, QPointingDevice *device, const QPoint &point)
{
    auto sequence = QTest::touchEvent(window, device, false);
    sequence.press(0, point, window);
    const bool pressDelivered = sequence.commit();
    sequence.release(0, point, window);
    return sequence.commit() && pressDelivered;
}

bool touchTap(QQuickWindow *window, QPointingDevice *device,
              QAccessibleInterface *interface)
{
    return touchTapAt(window, device, itemSceneRect(interface, window).center().toPoint());
}

bool touchDrag(QQuickWindow *window, QPointingDevice *device,
               const QPoint &from, const QPoint &to)
{
    auto sequence = QTest::touchEvent(window, device, false);
    sequence.press(0, from, window);
    if (!sequence.commit()) return false;
    QTest::qWait(60);
    const QPoint activationPoint = from + (to - from) / 4;
    sequence.move(0, activationPoint, window);
    if (!sequence.commit()) return false;
    QTest::qWait(60);
    sequence.move(0, to, window);
    if (!sequence.commit()) return false;
    QTest::qWait(60);
    sequence.release(0, to, window);
    return sequence.commit();
}

bool touchTapEditor(QQuickWindow *window, QPointingDevice *device, QQuickItem *field)
{
    const QPointF scenePoint = field->mapToScene(
        QPointF(field->width() / 2.0, field->height() - 24.0));
    return touchTapAt(window, device, scenePoint.toPoint());
}

bool isDescendantOf(QObject *object, QObject *ancestor)
{
    while (object) {
        if (object == ancestor) return true;
        object = object->parent();
    }
    return false;
}

QAccessibleInterface *findAccessibleByObjectName(
    QAccessibleInterface *root, const QString &objectName,
    QSet<QAccessibleInterface *> *visited = nullptr)
{
    if (!root || !root->isValid()) return nullptr;

    QSet<QAccessibleInterface *> localVisited;
    if (!visited) visited = &localVisited;
    if (visited->contains(root)) return nullptr;
    visited->insert(root);

    if (!root->state().invisible && root->object()
        && root->object()->objectName() == objectName) {
        return root;
    }
    for (int index = 0; index < root->childCount(); ++index) {
        if (QAccessibleInterface *match = findAccessibleByObjectName(
                root->child(index), objectName, visited)) {
            return match;
        }
    }
    return nullptr;
}

} // namespace

void QmlNavigationTest::loadsAndSwitchesEveryPrimaryPage()
{
    QAccessible::setActive(true);

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
    QVERIFY2(!QGuiApplication::font().family().isEmpty(),
             "应用必须继承可用的系统字体");
    const QByteArray mainSource = readFile(
        QStringLiteral(FITTRACK_SOURCE_DIR "/src/app/main.cpp"));
    const QByteArray appDialogSource = readFile(
        QStringLiteral(FITTRACK_SOURCE_DIR "/qml/components/AppDialog.qml"));
    const QByteArray confirmDialogSource = readFile(
        QStringLiteral(FITTRACK_SOURCE_DIR "/qml/components/ConfirmDialog.qml"));
    QVERIFY2(isValidUtf8(mainSource), "main.cpp 必须保持有效 UTF-8 编码");
    QVERIFY2(isValidUtf8(appDialogSource), "AppDialog.qml 必须保持有效 UTF-8 编码");
    QVERIFY2(isValidUtf8(confirmDialogSource),
             "ConfirmDialog.qml 必须保持有效 UTF-8 编码");
    QVERIFY2(!mainSource.contains("addApplicationFont")
                 && !mainSource.contains("setFont("),
             "应用不得覆盖 Android 或桌面系统字体");
    window->resize(360, 800);
    window->update();
    QTest::qWait(200);
    QAccessibleInterface *accessibleRoot = QAccessible::queryAccessibleInterface(window);
    QVERIFY(accessibleRoot);
    auto *touchDevice = QTest::createTouchDevice();
    QVERIFY(touchDevice);

    QObject *navigation = root->findChild<QObject *>(QStringLiteral("navigation"));
    QObject *stack = root->findChild<QObject *>(QStringLiteral("mainStack"));
    QObject *historyPage = root->findChild<QObject *>(QStringLiteral("historyPage"));
    QObject *insightsTabs = root->findChild<QObject *>(QStringLiteral("insightsTabs"));
    QObject *cardioEditor = root->findChild<QObject *>(QStringLiteral("cardioEditor"));
    QObject *targetRepsDialog = root->findChild<QObject *>(QStringLiteral("targetRepsDialog"));
    QVERIFY(navigation);
    QVERIFY(stack);
    QVERIFY(historyPage);
    QVERIFY(insightsTabs);
    QVERIFY(cardioEditor);
    QVERIFY(targetRepsDialog);

    QAccessibleInterface *startTraining = findAccessibleByName(
        accessibleRoot, QStringLiteral("开始训练"), QAccessible::Button);
    QVERIFY2(startTraining, "首页的开始训练按钮必须暴露给 TalkBack");
    QVERIFY(startTraining->state().focusable);
    QVERIFY(isTouchTargetAtLeast(startTraining, window, 48));
    QVERIFY(startTraining->actionInterface());
    QVERIFY(startTraining->actionInterface()->actionNames().contains(
        QAccessibleActionInterface::pressAction()));
    QVERIFY(touchTap(window, touchDevice, startTraining));
    QTRY_VERIFY(workoutController.preparing());
    QObject *preparationPage = root->findChild<QObject *>(
        QStringLiteral("workoutPreparationPage"));
    QObject *commitPreparation = root->findChild<QObject *>(
        QStringLiteral("commitPreparationButton"));
    QVERIFY(preparationPage);
    QVERIFY(commitPreparation);
    QTRY_VERIFY(preparationPage->property("visible").toBool());
    QSqlQuery preparationCount(databaseManager.database());
    QVERIFY(preparationCount.exec(QStringLiteral("SELECT COUNT(*) FROM workout_session")));
    QVERIFY(preparationCount.next());
    QCOMPARE(preparationCount.value(0).toInt(), 0);
    const QString preparationScreenshotDirectory = QStringLiteral(FITTRACK_SCREENSHOT_DIR);
    QVERIFY(QDir().mkpath(preparationScreenshotDirectory));
    window->update();
    QTest::qWait(100);
    QVERIFY(window->grabWindow().save(QDir(preparationScreenshotDirectory).filePath(
        QStringLiteral("workout-preparation-360x800.png"))));

    QVERIFY(root->setProperty("fontScale", 2.0));
    window->update();
    QTest::qWait(120);
    auto *commitPreparationItem = qobject_cast<QQuickItem *>(commitPreparation);
    QVERIFY(commitPreparationItem);
    const QRectF commitRect = commitPreparationItem->mapRectToScene(
        commitPreparationItem->boundingRect());
    QVERIFY(commitRect.width() >= 48 && commitRect.height() >= 48);
    QVERIFY(commitRect.left() >= -0.5 && commitRect.right() <= window->width() + 0.5);
    QVERIFY(commitRect.top() >= -0.5 && commitRect.bottom() <= window->height() + 0.5);
    QVERIFY(window->grabWindow().save(QDir(preparationScreenshotDirectory).filePath(
        QStringLiteral("workout-preparation-font-200-360x800.png"))));
    QVERIFY(root->setProperty("fontScale", 1.0));

    const QVariantMap preparedExercise = workoutController.preparation()
                                             .value(QStringLiteral("exercises"))
                                             .toList().first().toMap();
    QAccessibleInterface *previewPreparedExercise = findAccessibleByObjectName(
        accessibleRoot, QStringLiteral("preparedExercisePreviewButton"));
    QVERIFY2(previewPreparedExercise, "准备页动作名称必须可以打开动作详情");
    previewPreparedExercise->actionInterface()->doAction(
        QAccessibleActionInterface::pressAction());
    QObject *sharedDetail = root->findChild<QObject *>(
        QStringLiteral("preparationExerciseDetailSheet"));
    QVERIFY(sharedDetail);
    QTRY_VERIFY(sharedDetail->property("visible").toBool());
    const QVariantMap detailExercise = sharedDetail->property("exercise").toMap();
    QVERIFY(!detailExercise.value(QStringLiteral("mediaItems")).toList().isEmpty());
    QAccessibleInterface *closePreparedDetail = findAccessibleByName(
        accessibleRoot, QStringLiteral("关闭动作详情"), QAccessible::Button);
    QVERIFY(closePreparedDetail);
    closePreparedDetail->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!sharedDetail->property("visible").toBool());

    QAccessibleInterface *parameters = findAccessibleByObjectName(
        accessibleRoot, QStringLiteral("preparedExerciseParametersButton"));
    QVERIFY(parameters);
    parameters->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *parameterSheet = root->findChild<QObject *>(
        QStringLiteral("preparationExerciseParameterSheet"));
    QObject *setsInput = parameterSheet ? parameterSheet->findChild<QObject *>(
        QStringLiteral("parameterSetsInput")) : nullptr;
    QObject *repsInput = parameterSheet ? parameterSheet->findChild<QObject *>(
        QStringLiteral("parameterRepsInput")) : nullptr;
    QObject *restInput = parameterSheet ? parameterSheet->findChild<QObject *>(
        QStringLiteral("parameterRestInput")) : nullptr;
    QVERIFY(parameterSheet);
    QVERIFY(setsInput);
    QVERIFY(repsInput);
    QVERIFY(restInput);
    QTRY_VERIFY(parameterSheet->property("visible").toBool());
    QVERIFY(setsInput->setProperty("value", 4));
    QVERIFY(repsInput->setProperty("text", QStringLiteral("12,10,8,6")));
    QVERIFY(restInput->setProperty("value", 45));
    QAccessibleInterface *saveParameters = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存"), QAccessible::Button);
    QVERIFY(saveParameters);
    saveParameters->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!parameterSheet->property("visible").toBool());
    QVariantMap editedExercise = workoutController.preparation()
                                     .value(QStringLiteral("exercises"))
                                     .toList().first().toMap();
    QCOMPARE(editedExercise.value(QStringLiteral("sets")).toInt(), 4);
    QCOMPARE(editedExercise.value(QStringLiteral("reps")).toString(),
             QStringLiteral("12,10,8,6"));
    QCOMPARE(editedExercise.value(QStringLiteral("restSeconds")).toInt(), 45);

    parameters = findAccessibleByObjectName(
        accessibleRoot, QStringLiteral("preparedExerciseParametersButton"));
    QVERIFY(parameters);
    parameters->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(parameterSheet->property("visible").toBool());
    QAccessibleInterface *restoreParameters = findAccessibleByName(
        accessibleRoot, QStringLiteral("恢复进入准备时的默认值"), QAccessible::Button);
    QVERIFY(restoreParameters);
    restoreParameters->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    editedExercise = workoutController.preparation()
                         .value(QStringLiteral("exercises"))
                         .toList().first().toMap();
    QCOMPARE(editedExercise.value(QStringLiteral("sets")).toInt(),
             preparedExercise.value(QStringLiteral("sets")).toInt());
    QCOMPARE(editedExercise.value(QStringLiteral("restSeconds")).toInt(),
             preparedExercise.value(QStringLiteral("restSeconds")).toInt());
    QVERIFY(QMetaObject::invokeMethod(parameterSheet, "close"));

    const QVariantList originalPreparationOrder = workoutController.preparation()
                                                      .value(QStringLiteral("exercises"))
                                                      .toList();
    QVERIFY(originalPreparationOrder.size() > 1);
    const QString firstDraftId = originalPreparationOrder.at(0).toMap()
                                     .value(QStringLiteral("draftId")).toString();
    const QString secondDraftId = originalPreparationOrder.at(1).toMap()
                                      .value(QStringLiteral("draftId")).toString();
    const QString firstDraftName = originalPreparationOrder.at(0).toMap()
                                       .value(QStringLiteral("name")).toString();
    QAccessibleInterface *openOrderSheet = findAccessibleByName(
        accessibleRoot, QStringLiteral("调整动作顺序"), QAccessible::Button);
    QVERIFY(openOrderSheet);
    openOrderSheet->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *preparationOrderSheet = root->findChild<QObject *>(
        QStringLiteral("preparationExerciseOrderSheet"));
    QVERIFY(preparationOrderSheet);
    QTRY_VERIFY(preparationOrderSheet->property("visible").toBool());
    QTest::qWait(250);
    QVERIFY(root->setProperty("fontScale", 2.0));
    window->update();
    QTest::qWait(120);
    QVERIFY(preparationOrderSheet->property("width").toReal() <= window->width() + 0.5);
    QVERIFY(preparationOrderSheet->property("height").toReal() <= window->height() + 0.5);
    QVERIFY(window->grabWindow().save(QDir(preparationScreenshotDirectory).filePath(
        QStringLiteral("exercise-order-font-200-360x800.png"))));
    QVERIFY(root->setProperty("fontScale", 1.0));
    window->update();
    QTest::qWait(120);
    QAccessibleInterface *moveFirstDown = findAccessibleByName(
        accessibleRoot, QStringLiteral("下移%1").arg(firstDraftName), QAccessible::Button);
    QVERIFY(moveFirstDown);
    const QRectF moveDownRect = itemSceneRect(moveFirstDown, window);
    QVERIFY2(isTouchTargetAtLeast(moveFirstDown, window, 48),
             qPrintable(QStringLiteral("排序按钮触控区不足：%1×%2")
                            .arg(moveDownRect.width()).arg(moveDownRect.height())));
    moveFirstDown->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QCOMPARE(preparationOrderSheet->property("draftItems").toList().first().toMap()
                 .value(QStringLiteral("draftId")).toString(), secondDraftId);
    QVERIFY(QMetaObject::invokeMethod(preparationOrderSheet, "reject"));
    QTRY_VERIFY(!preparationOrderSheet->property("visible").toBool());
    QCOMPARE(workoutController.preparation().value(QStringLiteral("exercises"))
                 .toList().first().toMap().value(QStringLiteral("draftId")).toString(),
             firstDraftId);

    openOrderSheet = findAccessibleByName(
        accessibleRoot, QStringLiteral("调整动作顺序"), QAccessible::Button);
    QVERIFY(openOrderSheet);
    openOrderSheet->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(preparationOrderSheet->property("visible").toBool());
    QTest::qWait(250);
    QAccessibleInterface *dragFirst = findAccessibleByName(
        accessibleRoot, QStringLiteral("拖动%1调整顺序").arg(firstDraftName),
        QAccessible::Button);
    QVERIFY(dragFirst);
    QVERIFY(isTouchTargetAtLeast(dragFirst, window, 48));
    const QPoint dragStart = itemSceneRect(dragFirst, window).center().toPoint();
    QVERIFY(touchDrag(window, touchDevice, dragStart, dragStart + QPoint(0, 132)));
    QTRY_COMPARE(preparationOrderSheet->property("draftItems").toList().first().toMap()
                     .value(QStringLiteral("draftId")).toString(), secondDraftId);
    QCOMPARE(workoutController.preparation().value(QStringLiteral("exercises"))
                 .toList().first().toMap().value(QStringLiteral("draftId")).toString(),
             firstDraftId);
    QVERIFY(window->grabWindow().save(QDir(preparationScreenshotDirectory).filePath(
        QStringLiteral("exercise-order-touch-360x800.png"))));
    QAccessibleInterface *saveOrder = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存顺序"), QAccessible::Button);
    QVERIFY(saveOrder);
    saveOrder->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!preparationOrderSheet->property("visible").toBool());
    QCOMPARE(workoutController.preparation().value(QStringLiteral("exercises"))
                 .toList().first().toMap().value(QStringLiteral("draftId")).toString(),
             secondDraftId);

    QAccessibleInterface *cancelPreparation = findAccessibleByName(
        accessibleRoot, QStringLiteral("取消训练准备"), QAccessible::Button);
    QVERIFY(cancelPreparation);
    cancelPreparation->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *cancelPreparationConfirm = root->findChild<QObject *>(
        QStringLiteral("cancelPreparationConfirmDialog"));
    QVERIFY(cancelPreparationConfirm);
    QTRY_VERIFY(cancelPreparationConfirm->property("visible").toBool());
    QVERIFY(QMetaObject::invokeMethod(cancelPreparationConfirm, "accept"));
    QTRY_VERIFY(!workoutController.preparing());
    QVERIFY(preparationCount.exec(QStringLiteral("SELECT COUNT(*) FROM workout_session")));
    QVERIFY(preparationCount.next());
    QCOMPARE(preparationCount.value(0).toInt(), 0);

    startTraining = findAccessibleByName(
        accessibleRoot, QStringLiteral("开始训练"), QAccessible::Button);
    QVERIFY(startTraining);
    startTraining->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(workoutController.preparing());
    QVERIFY(workoutController.updatePreparedExercise(
        workoutController.preparation().value(QStringLiteral("exercises"))
            .toList().first().toMap().value(QStringLiteral("draftId")).toString(),
        4, QStringLiteral("12,10,8,6"), 45));
    QAccessibleInterface *startPreparedWorkout = findAccessibleByName(
        accessibleRoot, QStringLiteral("开始本次训练"), QAccessible::Button);
    QVERIFY(startPreparedWorkout);
    QVERIFY(isTouchTargetAtLeast(startPreparedWorkout, window, 48));
    startPreparedWorkout->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(workoutController.active());
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 2);
    QCOMPARE(workoutController.exercises().first().toMap()
                 .value(QStringLiteral("restSeconds")).toInt(), 45);
    QVERIFY(workoutController.discardWorkout());
    QVERIFY(navigation->setProperty("currentIndex", 0));
    QTest::qWait(80);

    const QStringList tabNames{
        QStringLiteral("首页"), QStringLiteral("计划"), QStringLiteral("训练"),
        QStringLiteral("动作"), QStringLiteral("分析"),
    };
    for (const QString &tabName : tabNames) {
        QAccessibleInterface *tab = findAccessibleByName(
            accessibleRoot, tabName, QAccessible::PageTab);
        QVERIFY2(tab, qPrintable(QStringLiteral("找不到底部标签：%1").arg(tabName)));
        QVERIFY(tab->state().focusable);
        QVERIFY(isTouchTargetAtLeast(tab, window, 48));
        QVERIFY(tab->actionInterface());
        QVERIFY2(tab->actionInterface()->actionNames().contains(
                     QAccessibleActionInterface::pressAction()),
                 qPrintable(QStringLiteral("底部标签不能由TalkBack激活：%1").arg(tabName)));
    }
    QAccessibleInterface *plansTab = findAccessibleByName(
        accessibleRoot, QStringLiteral("计划"), QAccessible::PageTab);
    QVERIFY(plansTab);
    plansTab->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 1);
    QTRY_VERIFY(plansTab->state().selected);
    QAccessibleInterface *homeTab = findAccessibleByName(
        accessibleRoot, QStringLiteral("首页"), QAccessible::PageTab);
    QVERIFY(homeTab);
    homeTab->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 0);
    QVERIFY(homeTab->state().selected);

    QVERIFY(workoutController.startSuggestedDay());
    const QString existingSessionId = workoutController.sessionId();
    plansTab->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 1);
    QAccessibleInterface *startPlanDay = findAccessibleByName(
        accessibleRoot, QStringLiteral("开始"), QAccessible::Button);
    QVERIFY2(startPlanDay, "计划页开始按钮必须可由 TalkBack 激活");
    startPlanDay->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *startConflictDialog = root->findChild<QObject *>(
        QStringLiteral("workoutStartConflictDialog"));
    QVERIFY(startConflictDialog);
    QTRY_VERIFY(startConflictDialog->property("visible").toBool());
    QCOMPARE(navigation->property("currentIndex").toInt(), 1);
    QCOMPARE(workoutController.sessionId(), existingSessionId);
    QVERIFY(workoutController.errorMessage().isEmpty());

    QVERIFY(root->setProperty("fontScale", 1.5));
    window->update();
    QTest::qWait(100);
    const QStringList conflictActions{
        QStringLiteral("继续当前训练"), QStringLiteral("保存并结束当前，再开始"),
        QStringLiteral("放弃当前训练，再开始"), QStringLiteral("取消"),
    };
    for (const QString &actionName : conflictActions) {
        QAccessibleInterface *action = findAccessibleByName(
            accessibleRoot, actionName, QAccessible::Button);
        QVERIFY2(action, qPrintable(QStringLiteral("冲突面板缺少操作：%1").arg(actionName)));
        QVERIFY2(isTouchTargetAtLeast(action, window, 48),
                 qPrintable(QStringLiteral("冲突面板触控区域不足：%1").arg(actionName)));
    }
    QAccessibleInterface *cancelConflict = findAccessibleByName(
        accessibleRoot, QStringLiteral("取消"), QAccessible::Button);
    cancelConflict->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!startConflictDialog->property("visible").toBool());
    QCOMPARE(navigation->property("currentIndex").toInt(), 1);
    QCOMPARE(workoutController.sessionId(), existingSessionId);

    QVERIFY(root->setProperty("fontScale", 1.0));
    startPlanDay = findAccessibleByName(accessibleRoot, QStringLiteral("开始"), QAccessible::Button);
    QVERIFY(startPlanDay);
    startPlanDay->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(startConflictDialog->property("visible").toBool());
    QAccessibleInterface *continueWorkout = findAccessibleByName(
        accessibleRoot, QStringLiteral("继续当前训练"), QAccessible::Button);
    QVERIFY(continueWorkout);
    continueWorkout->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 2);
    QCOMPARE(workoutController.sessionId(), existingSessionId);
    QVERIFY(workoutController.discardWorkout());
    QVERIFY(navigation->setProperty("currentIndex", 0));

    QSqlQuery legacyRecovery(databaseManager.database());
    QVERIFY(legacyRecovery.exec(QStringLiteral(
        "DROP TRIGGER workout_session_single_active_insert")));
    QVERIFY(legacyRecovery.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) VALUES"
        "('recovery-a','恢复训练 A','2026-07-14T08:00:00Z','active'),"
        "('recovery-b','恢复训练 B','2026-07-14T09:00:00Z','active')")));
    workoutController.reloadAfterRestore();
    QCOMPARE(workoutController.sessionState(), QStringLiteral("RecoveryRequired"));
    QVERIFY(navigation->setProperty("currentIndex", 1));
    startPlanDay = findAccessibleByName(accessibleRoot, QStringLiteral("开始"), QAccessible::Button);
    QVERIFY(startPlanDay);
    startPlanDay->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *recoveryDialog = root->findChild<QObject *>(QStringLiteral("workoutRecoveryDialog"));
    QVERIFY(recoveryDialog);
    QTRY_VERIFY(recoveryDialog->property("visible").toBool());
    QCOMPARE(navigation->property("currentIndex").toInt(), 1);

    QAccessibleInterface *recoveryChoice = findAccessibleByName(
        accessibleRoot, QStringLiteral("恢复训练 B"), QAccessible::Button);
    QVERIFY(recoveryChoice);
    recoveryChoice->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QVERIFY(root->setProperty("fontScale", 1.5));
    window->update();
    QTest::qWait(100);
    QAccessibleInterface *preserveRecovery = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存其他记录并继续所选"), QAccessible::Button);
    QAccessibleInterface *discardRecovery = findAccessibleByName(
        accessibleRoot, QStringLiteral("删除其他记录并继续所选"), QAccessible::Button);
    QVERIFY(preserveRecovery);
    QVERIFY(discardRecovery);
    QVERIFY(isTouchTargetAtLeast(preserveRecovery, window, 48));
    QVERIFY(isTouchTargetAtLeast(discardRecovery, window, 48));
    discardRecovery->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QObject *discardOtherWorkoutsConfirm = root->findChild<QObject *>(
        QStringLiteral("discardOtherWorkoutsConfirmDialog"));
    QVERIFY(discardOtherWorkoutsConfirm);
    QTRY_VERIFY(discardOtherWorkoutsConfirm->property("visible").toBool());
    QVERIFY(QMetaObject::invokeMethod(discardOtherWorkoutsConfirm, "reject"));
    QTRY_VERIFY(!discardOtherWorkoutsConfirm->property("visible").toBool());
    QTest::qWait(250);
    QCOMPARE(workoutController.sessionState(), QStringLiteral("RecoveryRequired"));
    QCOMPARE(recoveryDialog->property("selectedSessionId").toString(),
             QStringLiteral("recovery-b"));
    preserveRecovery = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存其他记录并继续所选"), QAccessible::Button);
    QVERIFY(preserveRecovery);
    QVERIFY(touchTap(window, touchDevice, preserveRecovery));
    QTRY_COMPARE(navigation->property("currentIndex").toInt(), 2);
    QCOMPARE(workoutController.sessionId(), QStringLiteral("recovery-b"));
    QCOMPARE(workoutController.sessionState(), QStringLiteral("Active"));
    QVERIFY(legacyRecovery.exec(QStringLiteral(
        "SELECT status FROM workout_session WHERE id='recovery-a'")));
    QVERIFY(legacyRecovery.next());
    QCOMPARE(legacyRecovery.value(0).toString(), QStringLiteral("completed"));
    QVERIFY(workoutController.discardWorkout());
    QVERIFY(legacyRecovery.exec(QStringLiteral(
        "CREATE TRIGGER workout_session_single_active_insert "
        "BEFORE INSERT ON workout_session WHEN NEW.status='active' "
        "AND EXISTS(SELECT 1 FROM workout_session WHERE status='active') "
        "BEGIN SELECT RAISE(ABORT, '已有进行中的训练'); END")));
    QVERIFY(root->setProperty("fontScale", 1.0));
    QVERIFY(navigation->setProperty("currentIndex", 0));

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

    exerciseModel.setSearchText(QStringLiteral("杠铃卧推"));
    QVERIFY(navigation->setProperty("currentIndex", 3));
    window->update();
    QTest::qWait(120);
    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("exercise-media"), viewport));

    QAccessibleInterface *benchPress = findAccessibleByName(
        accessibleRoot, QStringLiteral("杠铃卧推"), QAccessible::Button);
    QVERIFY2(benchPress, "动作列表项必须暴露动作名称");
    QVERIFY(benchPress->actionInterface());
    QVERIFY(benchPress->actionInterface()->actionNames().contains(
        QAccessibleActionInterface::pressAction()));
    benchPress->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    sharedDetail = root->findChild<QObject *>(QStringLiteral("libraryExerciseDetailSheet"));
    QObject *mediaCredit = sharedDetail ? sharedDetail->findChild<QObject *>(
        QStringLiteral("sharedExerciseMediaCredit")) : nullptr;
    QObject *detailImage = sharedDetail ? sharedDetail->findChild<QObject *>(
        QStringLiteral("sharedExerciseDetailImage")) : nullptr;
    QVERIFY(sharedDetail);
    QVERIFY(detailImage);
    QVERIFY(mediaCredit);
    QTRY_VERIFY(sharedDetail->property("visible").toBool());
    QTRY_VERIFY(mediaCredit->property("visible").toBool());
    QTRY_VERIFY(detailImage->property("visible").toBool());
    QVERIFY(capture(QStringLiteral("exercise-detail-media-credit"), QSize(360, 800)));
    const QVariantMap libraryDetailExercise = sharedDetail->property("exercise").toMap();
    QCOMPARE(libraryDetailExercise.value(QStringLiteral("name")).toString(),
             QStringLiteral("杠铃卧推"));
    QVERIFY(!libraryDetailExercise.value(QStringLiteral("steps")).toList().isEmpty());
    QVERIFY(!libraryDetailExercise.value(QStringLiteral("mediaItems")).toList().isEmpty());
    QAccessibleInterface *detailImageInterface =
        QAccessible::queryAccessibleInterface(detailImage);
    QVERIFY(detailImageInterface);
    QCOMPARE(detailImageInterface->role(), QAccessible::Graphic);
    QVERIFY(!detailImageInterface->text(QAccessible::Name).isEmpty());
    QAccessibleInterface *mediaCreditInterface =
        QAccessible::queryAccessibleInterface(mediaCredit);
    QVERIFY(mediaCreditInterface);
    QCOMPARE(mediaCreditInterface->text(QAccessible::Name), QStringLiteral("图片来源"));
    QVERIFY(!mediaCreditInterface->text(QAccessible::Description).isEmpty());
    QVERIFY(!mediaCreditInterface->actionInterface()
            || !mediaCreditInterface->actionInterface()->actionNames().contains(
                QAccessibleActionInterface::pressAction()));
    QAccessibleInterface *nextExerciseImage = findAccessibleByName(
        accessibleRoot, QStringLiteral("下一张动作图"), QAccessible::Button);
    QVERIFY2(!nextExerciseImage, "每个动作只打包一张已审核的可分发动作图");
    QVERIFY(mediaCreditInterface->text(QAccessible::Description)
                .contains(QStringLiteral("Public domain")));
    QObject *detailScroll = root->findChild<QObject *>(
        QStringLiteral("sharedExerciseDetailScroll"));
    QVERIFY(detailScroll);
    QObject *detailFlickable = detailScroll->property("contentItem").value<QObject *>();
    QVERIFY(detailFlickable);
    const qreal maximumContentY = qMax(
        0.0, detailFlickable->property("contentHeight").toReal()
                 - detailFlickable->property("height").toReal());
    QVERIFY(detailFlickable->setProperty("contentY", maximumContentY));
    QTest::qWait(120);
    QVERIFY(capture(QStringLiteral("exercise-detail-references"), QSize(360, 800)));
    const QByteArray exercisePageSource = readFile(
        QStringLiteral(FITTRACK_SOURCE_DIR "/qml/pages/ExerciseLibraryPage.qml"));
    QVERIFY2(!exercisePageSource.contains("Qt.openUrlExternally"),
             "动作详情不得重新加入教学视频或媒体外链入口");
    QAccessibleInterface *closeExerciseDetail = findAccessibleByName(
        accessibleRoot, QStringLiteral("关闭动作详情"), QAccessible::Button);
    QVERIFY(closeExerciseDetail);
    QVERIFY(closeExerciseDetail->actionInterface());
    QVERIFY(closeExerciseDetail->actionInterface()->actionNames().contains(
        QAccessibleActionInterface::pressAction()));
    closeExerciseDetail->actionInterface()->doAction(
        QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!sharedDetail->property("visible").toBool());
    exerciseModel.setSearchText({});

    const QString systemPlanId = planManagement.selectedPlan()
                                     .value(QStringLiteral("id")).toString();
    QVERIFY(!systemPlanId.isEmpty());
    QVERIFY(planManagement.copyPlan(systemPlanId, QStringLiteral("我的三分化")));
    const QString personalDayId = planManagement.selectedPlan()
                                      .value(QStringLiteral("days")).toList().first()
                                      .toMap().value(QStringLiteral("id")).toString();
    QVERIFY(planManagement.setCardio(personalDayId, QStringLiteral("TreadmillIncline"),
                                     30, 9.0, 5.0, -1.0, QStringLiteral("力量后完成")));
    QVERIFY(navigation->setProperty("currentIndex", 1));
    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("plans-editable"), viewport));
    const QVariantMap personalDay = planManagement.selectedPlan()
                                        .value(QStringLiteral("days")).toList().first().toMap();
    QObject *planOrderSheet = root->findChild<QObject *>(
        QStringLiteral("planExerciseOrderSheet"));
    QVERIFY(planOrderSheet);
    QVariantList planOrder = personalDay.value(QStringLiteral("exercises")).toList();
    QVERIFY(planOrder.size() > 1);
    const QString planSecondExerciseId = planOrder.at(1).toMap()
                                             .value(QStringLiteral("id")).toString();
    QVERIFY(QMetaObject::invokeMethod(
        planOrderSheet, "openExercises",
        Q_ARG(QVariant, QVariant(planOrder)), Q_ARG(QVariant, QVariant("id")),
        Q_ARG(QVariant, QVariant(personalDayId))));
    QTRY_VERIFY(planOrderSheet->property("visible").toBool());
    planOrder.move(1, 0);
    QVERIFY(planOrderSheet->setProperty("draftItems", planOrder));
    QAccessibleInterface *savePlanOrder = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存顺序"), QAccessible::Button);
    QVERIFY(savePlanOrder);
    savePlanOrder->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!planOrderSheet->property("visible").toBool());
    QCOMPARE(planManagement.selectedPlan().value(QStringLiteral("days")).toList()
                 .first().toMap().value(QStringLiteral("exercises")).toList()
                 .first().toMap().value(QStringLiteral("id")).toString(),
             planSecondExerciseId);
    for (const QSize &viewport : viewports) {
        window->resize(viewport);
        QVERIFY(QMetaObject::invokeMethod(cardioEditor, "openForDay",
                                          Q_ARG(QVariant, QVariant(personalDay))));
        QTest::qWait(100);
        QVERIFY(cardioEditor->property("width").toReal() <= viewport.width());
        QVERIFY(cardioEditor->property("height").toReal() <= viewport.height());
        QVERIFY(capture(QStringLiteral("plan-cardio-dialog"), viewport));
        QVERIFY(QMetaObject::invokeMethod(cardioEditor, "close"));
    }

    QVERIFY(workoutController.startPlanDay(personalDayId));
    QObject *workoutOrderSheet = root->findChild<QObject *>(
        QStringLiteral("workoutExerciseOrderSheet"));
    QVERIFY(workoutOrderSheet);
    QVariantList workoutOrder = workoutController.exercises();
    QVERIFY(workoutOrder.size() > 1);
    QStringList originalWorkoutIds;
    for (const QVariant &exercise : std::as_const(workoutOrder))
        originalWorkoutIds.append(exercise.toMap().value(QStringLiteral("id")).toString());
    const QString workoutSecondExerciseId = workoutOrder.at(1).toMap()
                                                .value(QStringLiteral("id")).toString();
    QVERIFY(QMetaObject::invokeMethod(
        workoutOrderSheet, "openExercises",
        Q_ARG(QVariant, QVariant(workoutOrder)), Q_ARG(QVariant, QVariant("id")),
        Q_ARG(QVariant, QVariant(""))));
    QTRY_VERIFY(workoutOrderSheet->property("visible").toBool());
    workoutOrder.move(1, 0);
    QVERIFY(workoutOrderSheet->setProperty("draftItems", workoutOrder));
    QAccessibleInterface *saveWorkoutOrder = findAccessibleByName(
        accessibleRoot, QStringLiteral("保存顺序"), QAccessible::Button);
    QVERIFY(saveWorkoutOrder);
    saveWorkoutOrder->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_VERIFY(!workoutOrderSheet->property("visible").toBool());
    QCOMPARE(workoutController.exercises().first().toMap()
                 .value(QStringLiteral("id")).toString(), workoutSecondExerciseId);
    QVERIFY(workoutController.reorderExercises(originalWorkoutIds));
    restTimer.start(180);
    QVERIFY(navigation->setProperty("currentIndex", 2));
    window->resize(360, 800);
    window->update();
    QTest::qWait(160);

    QAccessibleInterface *trainingTab = findAccessibleByName(
        accessibleRoot, QStringLiteral("训练"), QAccessible::PageTab);
    QVERIFY(trainingTab);
    QVERIFY(trainingTab->state().selected);
    QAccessibleInterface *weightField = findAccessibleByName(
        accessibleRoot, QStringLiteral("实际重量"), QAccessible::EditableText);
    QAccessibleInterface *repsField = findAccessibleByName(
        accessibleRoot, QStringLiteral("实际次数"), QAccessible::EditableText);
    QAccessibleInterface *completeSet = findAccessibleByName(
        accessibleRoot, QStringLiteral("完成本组"), QAccessible::Button);
    QAccessibleInterface *openTimer = findAccessibleByName(
        accessibleRoot, QStringLiteral("计时"), QAccessible::Button);
    QVERIFY2(weightField, "重量输入必须有稳定的可访问名称和编辑角色");
    QVERIFY2(repsField, "次数输入必须有稳定的可访问名称和编辑角色");
    QVERIFY2(completeSet, "完成本组必须暴露为按钮");
    QVERIFY2(openTimer, "计时入口必须暴露为按钮");
    QVERIFY(weightField->state().focusable);
    QVERIFY(repsField->state().focusable);
    QVERIFY(openTimer->state().focusable);
    auto *weightControl = qobject_cast<QQuickItem *>(
        root->findChild<QObject *>(QStringLiteral("setWeightField")));
    auto *repsControl = qobject_cast<QQuickItem *>(
        root->findChild<QObject *>(QStringLiteral("setRepsField")));
    QVERIFY(weightControl);
    QVERIFY(repsControl);
    QVERIFY(weightControl->width() >= 48 && weightControl->height() >= 48);
    QVERIFY(repsControl->width() >= 48 && repsControl->height() >= 48);
    QVERIFY(isTouchTargetAtLeast(completeSet, window, 48));
    QVERIFY(isTouchTargetAtLeast(openTimer, window, 48));

    const QVariantMap firstExercise = workoutController.exercises().first().toMap();
    const QVariantMap firstSet = firstExercise.value(QStringLiteral("sets")).toList().first().toMap();

    qputenv("FITTRACK_FONT_SCALE", "1.3");
    QVERIFY(root->setProperty("fontScale", 1.3));
    window->update();
    QTest::qWait(160);
    QVERIFY(capture(QStringLiteral("training-large-font-130"), QSize(360, 800)));
    const QStringList coreObjectNames{
        QStringLiteral("currentSetTargetButton"), QStringLiteral("openRestTimerButton"),
        QStringLiteral("setWeightField"), QStringLiteral("setRepsField"),
        QStringLiteral("completeSetButton"),
    };
    for (const QString &objectName : coreObjectNames) {
        QObject *object = root->findChild<QObject *>(objectName);
        QVERIFY2(object, qPrintable(QStringLiteral("找不到核心控件：%1").arg(objectName)));
        auto *item = qobject_cast<QQuickItem *>(object);
        QVERIFY(item);
        const QRectF rect = item->mapRectToScene(item->boundingRect());
        QVERIFY2(rect.left() >= -0.5 && rect.right() <= window->width() + 0.5,
                 qPrintable(QStringLiteral("大字体下控件横向溢出：%1").arg(objectName)));
        QVERIFY2(rect.top() >= -0.5 && rect.bottom() <= window->height() + 0.5,
                 qPrintable(QStringLiteral("大字体下控件纵向溢出：%1").arg(objectName)));
    }

    qputenv("FITTRACK_FONT_SCALE", "1.5");
    QVERIFY(root->setProperty("fontScale", 1.5));
    window->resize(360, 640);
    window->update();
    QTest::qWait(160);
    QVERIFY(capture(QStringLiteral("training-large-font-150"), QSize(360, 640)));
    for (const QString &objectName : coreObjectNames) {
        auto *item = qobject_cast<QQuickItem *>(root->findChild<QObject *>(objectName));
        QVERIFY2(item, qPrintable(QStringLiteral("找不到 1.5 倍字体核心控件：%1")
                                      .arg(objectName)));
        const QRectF rect = item->mapRectToScene(item->boundingRect());
        QVERIFY2(rect.left() >= -0.5 && rect.right() <= window->width() + 0.5,
                 qPrintable(QStringLiteral("1.5 倍字体下控件横向溢出：%1")
                                .arg(objectName)));
        QVERIFY2(rect.top() >= -0.5 && rect.bottom() <= window->height() + 0.5,
                 qPrintable(QStringLiteral("1.5 倍字体下控件纵向溢出：%1")
                                .arg(objectName)));
    }
    const QStringList trainingDialogNames{
        QStringLiteral("sessionActionsDialog"),
        QStringLiteral("exerciseActionsDialog"),
        QStringLiteral("exercisePickerDialog"),
        QStringLiteral("configureExerciseDialog"),
        QStringLiteral("editCompletedSetDialog"),
        QStringLiteral("targetRepsDialog"),
        QStringLiteral("appendSetDialog"),
        QStringLiteral("restTimerDialog"),
        QStringLiteral("equipmentChoiceDialog"),
        QStringLiteral("createGymDialog"),
        QStringLiteral("createEquipmentDialog"),
        QStringLiteral("exerciseNotesDialog"),
        QStringLiteral("sessionNotesDialog"),
        QStringLiteral("savePlanDialog"),
    };
    const QByteArray trainingPageSource = readFile(
        QStringLiteral(FITTRACK_SOURCE_DIR "/qml/pages/TrainingPage.qml"));
    QVERIFY2(!trainingPageSource.contains("\n    Dialog {")
                 && !trainingPageSource.contains("\n    Menu {"),
             "训练页不得重新加入桌面式原生 Dialog 或 Menu");
    for (const QString &dialogName : trainingDialogNames) {
        QObject *dialog = root->findChild<QObject *>(dialogName);
        QVERIFY2(dialog, qPrintable(QStringLiteral("找不到训练弹窗：%1").arg(dialogName)));
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(dialog->property("visible").toBool());
        QObject *initialFocusItem = dialog->property("initialFocusItem").value<QObject *>();
        QVERIFY2(initialFocusItem,
                 qPrintable(QStringLiteral("训练弹窗缺少初始焦点：%1").arg(dialogName)));
        QTRY_VERIFY(window->activeFocusItem() == initialFocusItem
                    || isDescendantOf(window->activeFocusItem(), initialFocusItem));
        QVERIFY2(dialog->property("width").toReal() <= window->width() + 0.5,
                 qPrintable(QStringLiteral("大字体下弹窗横向溢出：%1").arg(dialogName)));
        QVERIFY2(dialog->property("height").toReal() <= window->height() + 0.5,
                 qPrintable(QStringLiteral("大字体下弹窗纵向溢出：%1").arg(dialogName)));
        auto *dialogFooter = qobject_cast<QQuickItem *>(dialog->property("footer").value<QObject *>());
        auto *dialogContent = qobject_cast<QQuickItem *>(dialog->property("contentItem").value<QObject *>());
        QVERIFY(dialogFooter);
        QVERIFY(dialogContent);
        const QRectF footerRect = dialogFooter->mapRectToScene(dialogFooter->boundingRect());
        const QRectF contentRect = dialogContent->mapRectToScene(dialogContent->boundingRect());
        QVERIFY2(contentRect.bottom() <= footerRect.top() + 0.5,
                 qPrintable(QStringLiteral("弹窗内容与页脚重叠：%1").arg(dialogName)));
        QObject *accessibleDialogItem = dialog->property("accessibleItem").value<QObject *>();
        QVERIFY(accessibleDialogItem);
        QAccessibleInterface *dialogInterface =
            QAccessible::queryAccessibleInterface(accessibleDialogItem);
        QVERIFY(dialogInterface);
        QCOMPARE(dialogInterface->role(), QAccessible::Dialog);
        QVERIFY2(!dialogInterface->text(QAccessible::Name).isEmpty(),
                 qPrintable(QStringLiteral("训练弹窗缺少TalkBack名称：%1").arg(dialogName)));
        const QStringList actionProperties{
            QStringLiteral("primaryText"), QStringLiteral("secondaryText"),
        };
        for (const QString &actionProperty : actionProperties) {
            const QString visibleProperty = actionProperty == QStringLiteral("primaryText")
                    ? QStringLiteral("primaryVisible") : QStringLiteral("secondaryVisible");
            const QByteArray visiblePropertyName = visibleProperty.toUtf8();
            if (!dialog->property(visiblePropertyName.constData()).toBool())
                continue;
            const QByteArray actionPropertyName = actionProperty.toUtf8();
            const QString actionName = dialog->property(actionPropertyName.constData()).toString();
            QAccessibleInterface *action = findAccessibleByName(
                accessibleRoot, actionName, QAccessible::Button);
            QVERIFY2(action,
                     qPrintable(QStringLiteral("找不到弹窗按钮：%1 / %2")
                                    .arg(dialogName, actionName)));
            QVERIFY2(isTouchTargetAtLeast(action, window, 48),
                     qPrintable(QStringLiteral("弹窗按钮触控区域不足 48dp：%1 / %2")
                                    .arg(dialogName, actionName)));
        }
        if (dialogName == QStringLiteral("editCompletedSetDialog")
            || dialogName == QStringLiteral("appendSetDialog")) {
            const QString checkBoxName = dialogName == QStringLiteral("editCompletedSetDialog")
                    ? QStringLiteral("editSetFailureCheckBox")
                    : QStringLiteral("appendSetFailureCheckBox");
            auto *checkBox = qobject_cast<QQuickItem *>(
                root->findChild<QObject *>(checkBoxName));
            QVERIFY(checkBox);
            QVERIFY2(checkBox->width() >= 48 && checkBox->height() >= 48,
                     qPrintable(QStringLiteral("力竭复选框触控区域不足 48dp：%1，%2 x %3")
                                    .arg(checkBoxName)
                                    .arg(checkBox->width())
                                    .arg(checkBox->height())));
        }
        if (dialogName == QStringLiteral("targetRepsDialog"))
            QVERIFY(capture(QStringLiteral("training-dialog-large-font-150"), QSize(360, 640)));
        if (dialogName == QStringLiteral("editCompletedSetDialog"))
            QVERIFY(capture(QStringLiteral("training-edit-set-large-font-150"),
                            QSize(360, 640)));
        if (dialogName == QStringLiteral("sessionActionsDialog")
            || dialogName == QStringLiteral("exerciseActionsDialog")) {
            QVERIFY(capture(QStringLiteral("training-") + dialogName,
                            QSize(360, 640)));
        }
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QTRY_VERIFY(!dialog->property("visible").toBool());
    }

    const QStringList trainingConfirmDialogNames{
        QStringLiteral("discardWorkoutConfirmDialog"),
        QStringLiteral("discardUnfinishedConfirmDialog"),
        QStringLiteral("removeExerciseConfirmDialog"),
        QStringLiteral("finishWorkoutConfirmDialog"),
    };
    for (const QString &dialogName : trainingConfirmDialogNames) {
        QObject *dialog = root->findChild<QObject *>(dialogName);
        QVERIFY2(dialog, qPrintable(QStringLiteral("找不到训练确认框：%1").arg(dialogName)));
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(dialog->property("visible").toBool());
        QVERIFY(dialog->property("stackButtons").toBool());
        QObject *accessibleDialogItem = dialog->property("accessibleItem").value<QObject *>();
        QVERIFY(accessibleDialogItem);
        QAccessibleInterface *dialogInterface =
            QAccessible::queryAccessibleInterface(accessibleDialogItem);
        QVERIFY(dialogInterface);
        QCOMPARE(dialogInterface->role(), QAccessible::Dialog);
        QVERIFY2(!dialogInterface->text(QAccessible::Name).isEmpty(),
                 qPrintable(QStringLiteral("训练确认框缺少TalkBack名称：%1")
                                .arg(dialogName)));
        QObject *cancelItem = dialog->property("secondaryActionItem").value<QObject *>();
        QVERIFY(cancelItem);
        QTRY_VERIFY(cancelItem->property("activeFocus").toBool());
        QAccessibleInterface *cancelAction =
            QAccessible::queryAccessibleInterface(cancelItem);
        QVERIFY(cancelAction);
        QCOMPARE(cancelAction->role(), QAccessible::Button);
        QVERIFY(isTouchTargetAtLeast(cancelAction, window, 48));
        const QString confirmText = dialog->property("confirmText").toString();
        QAccessibleInterface *confirmAction = findAccessibleByName(
            accessibleRoot, confirmText, QAccessible::Button);
        QVERIFY(confirmAction);
        QVERIFY(isTouchTargetAtLeast(confirmAction, window, 48));
        QVERIFY2(dialog->property("width").toReal() <= window->width() + 0.5
                     && dialog->property("height").toReal() <= window->height() + 0.5,
                 qPrintable(QStringLiteral("训练确认框在大字体下溢出：%1")
                                .arg(dialogName)));
        if (dialogName == QStringLiteral("discardWorkoutConfirmDialog"))
            QVERIFY(capture(QStringLiteral("training-confirm-large-font-150"),
                            QSize(360, 640)));
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QTRY_VERIFY(!dialog->property("visible").toBool());
    }

    QObject *restTimerDialog = root->findChild<QObject *>(QStringLiteral("restTimerDialog"));
    QVERIFY(restTimerDialog);
    QVERIFY(QMetaObject::invokeMethod(restTimerDialog, "open"));
    QTRY_VERIFY(restTimerDialog->property("visible").toBool());
    QAccessibleInterface *twoMinuteTimer = findAccessibleByName(
        accessibleRoot, QStringLiteral("2 分钟"), QAccessible::Button);
    QVERIFY(twoMinuteTimer);
    QTRY_VERIFY_WITH_TIMEOUT(isTouchTargetAtLeast(twoMinuteTimer, window, 48), 1000);
    const QRectF twoMinuteTimerRect = itemSceneRect(twoMinuteTimer, window);
    QVERIFY2(twoMinuteTimerRect.width() >= 48 && twoMinuteTimerRect.height() >= 48,
             qPrintable(QStringLiteral("2 分钟触控区域不足：%1 x %2，类型 %3")
                            .arg(twoMinuteTimerRect.width())
                            .arg(twoMinuteTimerRect.height())
                            .arg(twoMinuteTimer->object()->metaObject()->className())));
    QVERIFY(capture(QStringLiteral("training-rest-timer-large-font-150"),
                    QSize(360, 640)));
    QVERIFY(touchTap(window, touchDevice, twoMinuteTimer));
    QTRY_COMPARE(restTimer.state(), fittrack::RestTimerController::State::Running);
    QTRY_VERIFY(!restTimerDialog->property("visible").toBool());

    QVERIFY(root->setProperty("fontScale", 1.0));
    qunsetenv("FITTRACK_FONT_SCALE");
    window->update();
    QTest::qWait(120);

    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("training-active"), viewport));
    for (const QSize &viewport : viewports) {
        window->resize(viewport);
        QVERIFY(QMetaObject::invokeMethod(targetRepsDialog, "openForSet",
                                          Q_ARG(QVariant, firstExercise.value(QStringLiteral("id"))),
                                          Q_ARG(QVariant, QVariant(firstSet))));
        QTest::qWait(100);
        QVERIFY(targetRepsDialog->property("width").toReal() <= viewport.width());
        QVERIFY(targetRepsDialog->property("height").toReal() <= viewport.height());
        QVERIFY(capture(QStringLiteral("training-target-dialog"), viewport));
        QVERIFY(QMetaObject::invokeMethod(targetRepsDialog, "close"));
    }
    QTRY_VERIFY(!targetRepsDialog->property("visible").toBool());
    QTest::qWait(120);
    restTimer.reset();

    weightField = findAccessibleByName(
        accessibleRoot, QStringLiteral("实际重量"), QAccessible::EditableText);
    repsField = findAccessibleByName(
        accessibleRoot, QStringLiteral("实际次数"), QAccessible::EditableText);
    completeSet = findAccessibleByName(
        accessibleRoot, QStringLiteral("完成本组"), QAccessible::Button);
    QVERIFY(weightField);
    QVERIFY(repsField);
    QVERIFY(completeSet);
    QVERIFY(touchTapEditor(window, touchDevice, weightControl));
    QTRY_VERIFY(isDescendantOf(window->activeFocusItem(), weightControl));
    QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(window, Qt::Key_4);
    QTest::keyClick(window, Qt::Key_0);
    QCOMPARE(weightField->object()->property("text").toString(), QStringLiteral("40"));
    QVERIFY(touchTapEditor(window, touchDevice, repsControl));
    QTRY_VERIFY(isDescendantOf(window->activeFocusItem(), repsControl));
    QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(window, Qt::Key_1);
    QTest::keyClick(window, Qt::Key_0);
    QCOMPARE(repsField->object()->property("text").toString(), QStringLiteral("10"));
    QTRY_VERIFY(!completeSet->state().disabled);
    QVERIFY(completeSet->state().focusable);
    QVERIFY(completeSet->actionInterface());
    QVERIFY(completeSet->actionInterface()->actionNames().contains(
        QAccessibleActionInterface::pressAction()));
    QVERIFY(touchTap(window, touchDevice, completeSet));
    QTRY_VERIFY(workoutController.exercises().first().toMap()
                    .value(QStringLiteral("sets")).toList().first().toMap()
                    .value(QStringLiteral("completed")).toBool());
    QTRY_COMPARE(restTimer.state(), fittrack::RestTimerController::State::Running);

    QAccessibleInterface *pauseTimer = findAccessibleByName(
        accessibleRoot, QStringLiteral("暂停"), QAccessible::Button);
    QVERIFY(pauseTimer);
    QVERIFY(isTouchTargetAtLeast(pauseTimer, window, 48));
    QVERIFY(pauseTimer->actionInterface());
    QVERIFY(pauseTimer->actionInterface()->actionNames().contains(
        QAccessibleActionInterface::pressAction()));
    pauseTimer->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(restTimer.state(), fittrack::RestTimerController::State::Paused);
    QAccessibleInterface *resumeTimer = findAccessibleByName(
        accessibleRoot, QStringLiteral("继续"), QAccessible::Button);
    QVERIFY(resumeTimer);
    QVERIFY(resumeTimer->actionInterface());
    resumeTimer->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(restTimer.state(), fittrack::RestTimerController::State::Running);
    QAccessibleInterface *stopTimer = findAccessibleByName(
        accessibleRoot, QStringLiteral("结束计时"), QAccessible::Button);
    QVERIFY(stopTimer);
    QVERIFY(isTouchTargetAtLeast(stopTimer, window, 48));
    QVERIFY(stopTimer->actionInterface());
    stopTimer->actionInterface()->doAction(QAccessibleActionInterface::pressAction());
    QTRY_COMPARE(restTimer.state(), fittrack::RestTimerController::State::Idle);

    QVERIFY(workoutController.finishWorkout());
    QCOMPARE(navigation->property("currentIndex").toInt(), 4);
    QCOMPARE(insightsTabs->property("currentIndex").toInt(), 1);
    QVERIFY(historyPage->property("showDetails").toBool());
    QVERIFY(historyPage->property("completionMode").toBool());
    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("workout-complete"), viewport));

    QVERIFY(QMetaObject::invokeMethod(historyPage, "continueToCardio"));
    QCOMPARE(insightsTabs->property("currentIndex").toInt(), 2);
    QVERIFY(!cardioController.pendingSessionId().isEmpty());
    QCOMPARE(cardioController.pendingTarget().value(QStringLiteral("type")).toString(),
             QStringLiteral("TreadmillIncline"));
    const QString completedSessionId = cardioController.pendingSessionId();

    QVariant reopenedSummary;
    QVERIFY(QMetaObject::invokeMethod(historyPage, "openCompletion",
                                     Q_RETURN_ARG(QVariant, reopenedSummary),
                                     Q_ARG(QVariant, completedSessionId)));
    QVERIFY(reopenedSummary.toBool());
    QVERIFY(QMetaObject::invokeMethod(historyPage, "dismissCompletion"));
    QCOMPARE(navigation->property("currentIndex").toInt(), 0);
    QVERIFY(cardioController.pendingSessionId().isEmpty());

    workoutHistory.reload();
    analyticsDashboard.reload();
    QVERIFY(!workoutHistory.sessions().isEmpty());
    QVERIFY(workoutHistory.selectSession(
        workoutHistory.sessions().first().toMap().value(QStringLiteral("id")).toString()));
    QVERIFY(historyPage->setProperty("showDetails", true));

    QVERIFY(navigation->setProperty("currentIndex", 4));
    QVERIFY(insightsTabs->setProperty("currentIndex", 0));
    for (const QSize &viewport : viewports)
        QVERIFY(capture(QStringLiteral("insights-data"), viewport));
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

    QVariant handled;
    QVERIFY(QMetaObject::invokeMethod(root, "handleBack", Q_RETURN_ARG(QVariant, handled)));
    QVERIFY(handled.toBool());
    QCOMPARE(insightsTabs->property("currentIndex").toInt(), 0);
    QVERIFY(QMetaObject::invokeMethod(root, "handleBack", Q_RETURN_ARG(QVariant, handled)));
    QVERIFY(handled.toBool());
    QCOMPARE(navigation->property("currentIndex").toInt(), 0);
    QVERIFY(QMetaObject::invokeMethod(root, "handleBack", Q_RETURN_ARG(QVariant, handled)));
    QVERIFY(!handled.toBool());
}

int main(int argc, char **argv)
{
    Q_INIT_RESOURCE(action_images);
    if (!qEnvironmentVariableIsSet("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "offscreen");
    if (!qEnvironmentVariableIsSet("QSG_RHI_BACKEND")) qputenv("QSG_RHI_BACKEND", "software");
    QGuiApplication app(argc, argv);
#ifdef Q_OS_WIN
    // The offscreen platform reports the generic "Sans Serif" alias instead of
    // the normal Windows UI font. Load the installed UI font by file so the
    // FreeType-backed offscreen renderer can resolve both Chinese and Latin text.
    const int systemFontId = QFontDatabase::addApplicationFont(
        QStringLiteral("C:/Windows/Fonts/msyh.ttc"));
    const QStringList systemFontFamilies =
        QFontDatabase::applicationFontFamilies(systemFontId);
    if (!systemFontFamilies.isEmpty())
        app.setFont(QFont(systemFontFamilies.constFirst()));
#endif
    QQuickStyle::setStyle(QStringLiteral("Material"));
    QmlNavigationTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_qmlnavigation.moc"
