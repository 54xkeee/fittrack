#pragma once

#include "graderepository.h"

#include <QMainWindow>

QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow() override;

private slots:
    void loginAdmin();
    void loginStudent();

private:
    void restoreLogin();
    Ui::MainWindow *ui;
    GradeRepository m_repository;
};

