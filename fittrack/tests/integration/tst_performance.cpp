#include "analytics/analyticsdashboardcontroller.h"
#include "exercises/exerciselistmodel.h"
#include "history/workouthistorycontroller.h"
#include "plans/planmanagementcontroller.h"
#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"
#include "storage/planseedimporter.h"
#include "training/workoutsessioncontroller.h"

#include <QFile>
#include <QSqlDriver>
#include <QSqlQuery>
#include <QTest>

#include <sqlite3.h>

namespace {

QByteArray readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray{};
}

QList<QByteArray> exerciseDocuments()
{
    return {
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-push.json")),
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-pull.json")),
        readFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/exercises-legs.json")),
    };
}

class SqlStatementCounter final
{
public:
    explicit SqlStatementCounter(const QSqlDatabase &database)
    {
        QVariant handle = database.driver()->handle();
        if (handle.isValid() && qstrcmp(handle.typeName(), "sqlite3*") == 0)
            m_database = *static_cast<sqlite3 **>(handle.data());
        if (m_database)
            sqlite3_trace_v2(m_database, SQLITE_TRACE_STMT, trace, this);
    }

    ~SqlStatementCounter()
    {
        if (m_database)
            sqlite3_trace_v2(m_database, 0, nullptr, nullptr);
    }

    int count() const { return m_count; }
    bool valid() const { return m_database != nullptr; }
    void reset() { m_count = 0; }

private:
    static int trace(unsigned, void *context, void *, void *)
    {
        ++static_cast<SqlStatementCounter *>(context)->m_count;
        return 0;
    }

    sqlite3 *m_database = nullptr;
    int m_count = 0;
};

} // namespace

class PerformanceTest final : public QObject
{
    Q_OBJECT

private slots:
    void catalogLoadUsesFixedQueries();
    void deferredCatalogDoesNotQueryUntilNeeded();
    void planDetailUsesFixedQueries();
    void activeWorkoutLoadUsesFixedQueries();
    void workoutHistoryDetailUsesFixedQueries();
    void analyticsUsesFixedQueries();
    void unchangedSeedsDoNotRewriteCatalog();
    void unchangedPlanSeedDoesNotRewriteCatalog();
};

void PerformanceTest::catalogLoadUsesFixedQueries()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    fittrack::ExerciseListModel model(manager.database());
    QCOMPARE(model.rowCount(), 58);
    qInfo() << "R4 baseline catalog statements" << counter.count();
    QVERIFY2(counter.count() <= 3, qPrintable(QStringLiteral(
        "动作目录仍存在 N+1 查询：%1 条 SQL").arg(counter.count())));
}

void PerformanceTest::deferredCatalogDoesNotQueryUntilNeeded()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    fittrack::ExerciseListModel model(manager.database(), documents, false);
    QCOMPARE(model.rowCount(), 0);
    QCOMPARE(counter.count(), 0);

    model.ensureLoaded();
    QCOMPARE(model.rowCount(), 58);
    QVERIFY2(counter.count() <= 3, qPrintable(QStringLiteral(
        "延迟动作目录首次加载超过 3 条 SQL：%1").arg(counter.count())));
}

void PerformanceTest::planDetailUsesFixedQueries()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    QVERIFY2(fittrack::PlanSeedImporter::importDocument(
                 manager.database(),
                 readFile(QStringLiteral(FITTRACK_SOURCE_DIR
                                         "/resources/data/tan-three-day-split.json")),
                 &error), qPrintable(error));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    fittrack::PlanManagementController controller(manager.database());
    QVERIFY(controller.plans().isEmpty());
    controller.ensureLoaded();
    QCOMPARE(controller.selectedPlan().value(QStringLiteral("days")).toList().size(), 3);
    qInfo() << "R4 baseline plan statements" << counter.count();
    QVERIFY2(counter.count() <= 6, qPrintable(QStringLiteral(
        "计划详情仍按训练日重复查询：%1 条 SQL").arg(counter.count())));
}

void PerformanceTest::activeWorkoutLoadUsesFixedQueries()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    fittrack::WorkoutSessionController setup(manager.database());
    QVERIFY(setup.startFreeWorkout(QStringLiteral("性能训练")));
    for (int index = 0; index < 12; ++index)
        QVERIFY(setup.addExercise(QStringLiteral("barbell-bench-press"), 4, QStringLiteral("8")));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    fittrack::WorkoutSessionController controller(manager.database());
    QVERIFY(controller.resumeUnfinished());
    QCOMPARE(controller.exercises().size(), 12);
    qInfo() << "R4 baseline workout statements" << counter.count();
    QVERIFY2(counter.count() <= 12, qPrintable(QStringLiteral(
        "训练恢复仍存在多层 N+1 查询：%1 条 SQL").arg(counter.count())));
}

void PerformanceTest::workoutHistoryDetailUsesFixedQueries()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    fittrack::WorkoutSessionController setup(manager.database());
    QVERIFY(setup.startFreeWorkout(QStringLiteral("性能训练")));
    const QString sessionId = setup.sessionId();
    for (int index = 0; index < 12; ++index)
        QVERIFY(setup.addExercise(QStringLiteral("barbell-bench-press"), 4, QStringLiteral("8")));
    QSqlQuery completeSets(manager.database());
    QVERIFY(completeSets.exec(QStringLiteral(
        "UPDATE set_record SET completed=1,weight_kg=20,actual_reps=8")));
    QVERIFY(setup.finishWorkout());

    fittrack::WorkoutHistoryController history(manager.database());
    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    QVERIFY(history.selectSession(sessionId));
    QCOMPARE(history.selectedSession().value(QStringLiteral("exerciseCount")).toInt(), 12);
    QCOMPARE(history.selectedSession().value(QStringLiteral("setCount")).toInt(), 48);
    qInfo() << "R4 history detail statements" << counter.count();
    QVERIFY2(counter.count() <= 5, qPrintable(QStringLiteral(
        "历史详情仍存在 N+1 查询：%1 条 SQL").arg(counter.count())));
}

void PerformanceTest::analyticsUsesFixedQueries()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    fittrack::WorkoutSessionController setup(manager.database());
    QVERIFY(setup.startFreeWorkout(QStringLiteral("性能训练")));
    for (int index = 0; index < 12; ++index)
        QVERIFY(setup.addExercise(QStringLiteral("barbell-bench-press"), 4, QStringLiteral("8")));
    QSqlQuery completeSets(manager.database());
    QVERIFY(completeSets.exec(QStringLiteral(
        "UPDATE set_record SET completed=1,weight_kg=20,actual_reps=8")));
    QVERIFY(setup.finishWorkout());

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    fittrack::AnalyticsDashboardController analytics(manager.database());
    qInfo() << "R4 analytics startup statements" << counter.count();
    QVERIFY2(counter.count() <= 3, qPrintable(QStringLiteral(
        "首页分析摘要超过 3 条 SQL：%1").arg(counter.count())));

    counter.reset();
    analytics.ensureLoaded();
    QCOMPARE(analytics.trend().size(), 12);
    qInfo() << "R4 analytics detail statements" << counter.count();
    QVERIFY2(counter.count() <= 5, qPrintable(QStringLiteral(
        "分析详情仍随训练量增长：%1 条 SQL").arg(counter.count())));

    counter.reset();
    analytics.reload();
    qInfo() << "R4 analytics reload statements" << counter.count();
    QVERIFY2(counter.count() <= 8, qPrintable(QStringLiteral(
        "7 天分析完整刷新超过 8 条 SQL：%1").arg(counter.count())));
}

void PerformanceTest::unchangedSeedsDoNotRewriteCatalog()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    qInfo() << "R4 baseline unchanged seed statements" << counter.count();
    QVERIFY2(counter.count() <= 1, qPrintable(QStringLiteral(
        "未变化动作种子仍重复写入：%1 条 SQL").arg(counter.count())));
}

void PerformanceTest::unchangedPlanSeedDoesNotRewriteCatalog()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    const auto documents = exerciseDocuments();
    QVERIFY2(fittrack::ExerciseSeedImporter::importDocuments(
                 manager.database(), documents, &error), qPrintable(error));
    const QByteArray plan = readFile(QStringLiteral(
        FITTRACK_SOURCE_DIR "/resources/data/tan-three-day-split.json"));
    QVERIFY2(fittrack::PlanSeedImporter::importDocument(
                 manager.database(), plan, &error), qPrintable(error));

    SqlStatementCounter counter(manager.database());
    QVERIFY(counter.valid());
    QVERIFY2(fittrack::PlanSeedImporter::importDocument(
                 manager.database(), plan, &error), qPrintable(error));
    qInfo() << "R4 unchanged plan seed statements" << counter.count();
    QVERIFY2(counter.count() <= 1, qPrintable(QStringLiteral(
        "未变化计划种子仍重复写入：%1 条 SQL").arg(counter.count())));
}

QTEST_GUILESS_MAIN(PerformanceTest)
#include "tst_performance.moc"
