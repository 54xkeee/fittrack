#pragma once

#include "graderepository.h"

#include <QMainWindow>

namespace Ui { class AdminWindow; }

class AdminWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit AdminWindow(GradeRepository *repository, QWidget *parent = nullptr);
    ~AdminWindow() override;
signals:
    void returnRequested();
private slots:
    void importFile();
    void exportFile();
    void addStudent();
    void deleteStudent();
    void sortStudents();
private:
    void refreshTable();
    void clearForm();
    Ui::AdminWindow *ui;
    GradeRepository *m_repository;
};

