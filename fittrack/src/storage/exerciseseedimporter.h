#pragma once

#include <QByteArray>
#include <QList>
#include <QSqlDatabase>
#include <QString>

namespace fittrack {

class ExerciseSeedImporter final
{
public:
    static bool importDocuments(
        const QSqlDatabase &database,
        const QList<QByteArray> &documents,
        QString *errorMessage = nullptr);
};

} // namespace fittrack
