#pragma once

#include "studentdata.h"
#include <QMainWindow>

namespace Ui { class StudentWindow; }

class StudentWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit StudentWindow(const StudentData &student, QWidget *parent = nullptr);
    ~StudentWindow() override;
signals:
    void returnRequested();
private:
    Ui::StudentWindow *ui;
};

