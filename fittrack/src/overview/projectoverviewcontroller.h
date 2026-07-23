#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantMap>

namespace fittrack {

class ProjectOverviewController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap summary READ summary NOTIFY summaryChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit ProjectOverviewController(QSqlDatabase database, QObject *parent = nullptr);

    QVariantMap summary() const;
    QString errorMessage() const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool createDemoData();

signals:
    void summaryChanged();
    void errorMessageChanged();
    void demoDataCreated();

private:
    void setError(const QString &message);
    qint64 tableCount(const QString &table, const QString &where = QString()) const;
    bool execute(const QString &statement, const QVariantList &values = {});

    QSqlDatabase m_database;
    QVariantMap m_summary;
    QString m_errorMessage;
};

} // namespace fittrack
