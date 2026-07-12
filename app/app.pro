QT += core gui widgets
CONFIG += c++17
TEMPLATE = app
TARGET = StudentGradeSystem

SOURCES += \
    main.cpp \
    mainwindow.cpp \
    adminwindow.cpp \
    studentwindow.cpp \
    studentdata.cpp \
    graderepository.cpp \
    authentication.cpp

HEADERS += \
    mainwindow.h \
    adminwindow.h \
    studentwindow.h \
    studentdata.h \
    graderepository.h \
    authentication.h

FORMS += mainwindow.ui adminwindow.ui studentwindow.ui
RESOURCES += resources.qrc

