#pragma once

#include <QSqlDatabase>
#include <QString>

namespace fittrack {

class DatabaseManager final
{
public:
    DatabaseManager();
    ~DatabaseManager();

    DatabaseManager(const DatabaseManager &) = delete;
    DatabaseManager &operator=(const DatabaseManager &) = delete;

    bool initialize(const QString &databasePath, QString *errorMessage = nullptr);
    QSqlDatabase database() const;

private:
    bool createSchema(QString *errorMessage);
    bool execute(const QString &statement, QString *errorMessage);

    QString m_connectionName;
};

} // namespace fittrack
