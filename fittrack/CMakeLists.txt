cmake_minimum_required(VERSION 3.21)

project(FitTrack VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Multimedia Qml Quick QuickControls2 Sql Test)

qt_standard_project_setup(REQUIRES 6.8)

add_library(fittrack_domain STATIC
    src/analytics/traininganalytics.cpp
    src/analytics/traininganalytics.h
    src/training/setrecord.h
)

target_include_directories(fittrack_domain PUBLIC src)
target_link_libraries(fittrack_domain PUBLIC Qt6::Core)

add_library(fittrack_storage STATIC
    src/storage/databasemanager.cpp
    src/storage/databasemanager.h
    src/storage/exerciseseedimporter.cpp
    src/storage/exerciseseedimporter.h
    src/storage/planseedimporter.cpp
    src/storage/planseedimporter.h
)

target_include_directories(fittrack_storage PUBLIC src)
target_link_libraries(fittrack_storage PUBLIC Qt6::Core Qt6::Sql)

add_library(fittrack_ui_models STATIC
    src/exercises/exerciselistmodel.cpp
    src/exercises/exerciselistmodel.h
)

target_include_directories(fittrack_ui_models PUBLIC src)
target_link_libraries(fittrack_ui_models PUBLIC fittrack_storage Qt6::Core Qt6::Sql)

add_library(fittrack_services STATIC
    src/analytics/analyticsdashboardcontroller.cpp
    src/analytics/analyticsdashboardcontroller.h
    src/history/workouthistorycontroller.cpp
    src/history/workouthistorycontroller.h
    src/plans/planmanagementcontroller.cpp
    src/plans/planmanagementcontroller.h
    src/timer/resttimercontroller.cpp
    src/timer/resttimercontroller.h
    src/timer/timeralertplayer.cpp
    src/timer/timeralertplayer.h
    src/training/workoutsessioncontroller.cpp
    src/training/workoutsessioncontroller.h
)

target_include_directories(fittrack_services PUBLIC src)
target_link_libraries(fittrack_services PUBLIC fittrack_domain Qt6::Core Qt6::Multimedia Qt6::Sql)

qt_add_executable(fittrack
    src/app/main.cpp
)

# MSYS2 Qt 6.9.1 qmlcachegen crashes on the root file after resolving the
# navigation page graph. Keep all pages cached and parse only Main.qml at runtime.
set_source_files_properties(qml/Main.qml PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)

qt_add_qml_module(fittrack
    URI FitTrack
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/components/StatCard.qml
        qml/components/TrendChart.qml
        qml/components/MuscleBars.qml
        qml/pages/HomePage.qml
        qml/pages/ExerciseLibraryPage.qml
        qml/pages/TrainingPage.qml
        qml/pages/HistoryPage.qml
        qml/pages/AnalysisPage.qml
        qml/pages/PlanPage.qml
        qml/pages/InsightsPage.qml
)

qt_add_resources(fittrack "seed_data"
    PREFIX "/data"
    BASE "resources/data"
    FILES
        resources/data/exercises-push.json
        resources/data/exercises-pull.json
        resources/data/exercises-legs.json
        resources/data/tan-three-day-split.json
)

file(GLOB_RECURSE ACTION_IMAGES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/resources/images/*"
)
add_library(fittrack_action_images STATIC)
qt_add_resources(fittrack_action_images "action_images"
    PREFIX "/"
    BASE "resources"
    FILES ${ACTION_IMAGES}
)
target_link_libraries(fittrack_action_images PUBLIC Qt6::Core)

target_link_libraries(fittrack PRIVATE
    fittrack_domain
    fittrack_storage
    fittrack_ui_models
    fittrack_services
    fittrack_action_images
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

include(CTest)
if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

install(TARGETS fittrack
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
