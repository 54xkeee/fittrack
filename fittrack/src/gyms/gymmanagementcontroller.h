#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>

namespace fittrack {

class GymManagementController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList gyms READ gyms NOTIFY dataChanged)
    Q_PROPERTY(QVariantList equipment READ equipment NOTIFY dataChanged)
    Q_PROPERTY(QString selectedGymId READ selectedGymId NOTIFY dataChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit GymManagementController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList gyms() const;
    QVariantList equipment() const;
    QString selectedGymId() const;
    QString errorMessage() const;

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void reload();
    Q_INVOKABLE bool selectGym(const QString &gymId);
    Q_INVOKABLE bool createGym(const QString &name);
    Q_INVOKABLE bool renameGym(const QString &gymId, const QString &name);
    Q_INVOKABLE bool removeGym(const QString &gymId);
    Q_INVOKABLE bool createEquipment(const QString &name, const QString &code = {},
                                     const QString &notes = {});
    Q_INVOKABLE bool updateEquipment(const QString &equipmentId, const QString &name,
                                     const QString &code = {}, const QString &notes = {});
    Q_INVOKABLE bool removeEquipment(const QString &equipmentId);

signals:
    void catalogChanged();
    void dataChanged();
    void errorMessageChanged();

private:
    bool exists(const QString &table, const QString &id) const;
    bool fail(const QString &message);
    void clearError();
    void loadEquipment();

    QSqlDatabase m_database;
    QVariantList m_gyms;
    QVariantList m_equipment;
    QString m_selectedGymId;
    QString m_errorMessage;
    bool m_loaded = false;
};

} // namespace fittrack
