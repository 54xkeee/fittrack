#include "studentdata.h"

#include <algorithm>

StudentData::StudentData(QString id, QString name, QString sex,
                         double english, double chinese, double math)
    : m_id(std::move(id)),
      m_name(std::move(name)),
      m_sex(std::move(sex)),
      m_english(english),
      m_chinese(chinese),
      m_math(math)
{
}

double StudentData::total() const
{
    return m_english + m_chinese + m_math;
}

double StudentData::average() const
{
    return total() / 3.0;
}

void sortAndRank(QVector<StudentData> &students)
{
    std::stable_sort(students.begin(), students.end(),
                     [](const StudentData &left, const StudentData &right) {
                         return left.total() > right.total();
                     });

    for (qsizetype index = 0; index < students.size(); ++index) {
        const bool tied = index > 0 && students[index].total() == students[index - 1].total();
        students[index].setRank(tied ? students[index - 1].rank() : static_cast<int>(index + 1));
    }
}
