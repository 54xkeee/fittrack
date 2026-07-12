#pragma once

#include "studentdata.h"

class GradeRepository
{
public:
    bool load(const QString &path, QString *error = nullptr);
    bool save(const QString &path, QString *error = nullptr) const;
    bool add(const StudentData &student, QString *error = nullptr);
    bool removeAt(int row, QString *error = nullptr);

    const QVector<StudentData> &students() const { return m_students; }
    const StudentData *findById(const QString &id) const;
    void sortByTotal();

private:
    static bool validate(const StudentData &student, QString *error);
    QVector<StudentData> m_students;
};

