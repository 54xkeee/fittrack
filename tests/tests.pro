QT += core testlib
QT -= gui
CONFIG += console testcase c++17
TEMPLATE = app
TARGET = test_core

INCLUDEPATH += ../app

SOURCES += \
    test_core.cpp \
    ../app/studentdata.cpp \
    ../app/graderepository.cpp \
    ../app/authentication.cpp

HEADERS += \
    ../app/studentdata.h \
    ../app/graderepository.h \
    ../app/authentication.h
