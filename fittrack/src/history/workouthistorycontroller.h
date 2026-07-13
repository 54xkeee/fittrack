#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

namespace fittrack {

class WorkoutHistoryController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY sessionsChanged)
    Q_PROPERTY(QVariantMap selectedSession READ selectedSession NOTIFY selectedSessionChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit WorkoutHistoryController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList sessions() const;
    bool hasMore() const;
    QVariantMap selectedSession() const;
    QString errorMessage() const;

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE bool selectSession(const QString &sessionId);
    Q_INVOKABLE bool updateCompletedSet(
        const QString &setId, double weightKg, int actualReps,
        bool toFailure = false, const QString &bodyweightLoadType = QStringLiteral("Bodyweight"));
    Q_INVOKABLE bool deleteSession(const QString &sessionId);

signals:
    void sessionsChanged();
    void selectedSessionChanged();
    void errorMessageChanged();

private:
    bool fail(const QString &message);
    void clearError();
    void loadPage(bool reset, int pageSize);

    QSqlDatabase m_database;
    QVariantList m_sessions;
    bool m_hasMore = false;
    QVariantMap m_selectedSession;
    QString m_errorMessage;
    bool m_loaded = false;
};

} // namespace fittrack
