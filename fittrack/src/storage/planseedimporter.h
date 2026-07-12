#pragma once

#include <QByteArray>
#include <QSqlDatabase>
#include <QString>

namespace fittrack {

class PlanSeedImporter final
{
public:
    static bool importDocument(
        const QSqlDatabase &database,
        const QByteArray &document,
        QString *errorMessage = nullptr);
};

} // namespace fittrack
