#include "authentication.h"

bool isAdminCredentials(const QString &account, const QString &password)
{
    return account == QStringLiteral("xmu123") && password == QStringLiteral("123456");
}

bool isStudentCredentials(const QString &account, const QString &password)
{
    if (account.size() != 9 || !account.startsWith(QStringLiteral("2312025")))
        return false;
    bool ok = false;
    const int suffix = account.right(2).toInt(&ok);
    if (!ok || suffix < 1 || suffix > 60)
        return false;
    return password == QStringLiteral("password%1").arg(suffix, 2, 10, QLatin1Char('0'));
}
