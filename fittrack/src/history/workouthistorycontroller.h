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
    Q_PROPERTY(QVariantMap selectedSession READ selectedSession NOTIFY selectedSessionChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit WorkoutHistoryController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList sessions() const;
    QVariantMap selectedSession() const;
    QString errorMessage() const;

    Q_INVOKABLE void reload();
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

    QSqlDatabase m_database;
    QVariantList m_sessions;
    QVariantMap m_selectedSession;
    QString m_errorMessage;
};

} // namespace fittrack
