cmake_minimum_required(VERSION 3.21)

project(FitTrack VERSION 0.1.0 LANGUAGES CXX)

if(ANDROID AND NOT DEFINED BUILD_TESTING)
    set(BUILD_TESTING OFF CACHE BOOL "Build FitTrack tests" FORCE)
endif()
include(CTest)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

set(FITTRACK_QT_COMPONENTS Core Gui Qml Quick QuickControls2 Sql)
if(NOT ANDROID)
    list(APPEND FITTRACK_QT_COMPONENTS Multimedia)
endif()
find_package(Qt6 6.9 REQUIRED COMPONENTS ${FITTRACK_QT_COMPONENTS})
if(BUILD_TESTING)
    find_package(Qt6 6.9 REQUIRED COMPONENTS Test)
    find_package(SQLite3 REQUIRED)
endif()

qt_standard_project_setup(REQUIRES 6.9)

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

set(FITTRACK_SERVICE_SOURCES
    src/analytics/analyticsdashboardcontroller.cpp
    src/analytics/analyticsdashboardcontroller.h
    src/backup/backupservice.cpp
    src/backup/backupservice.h
    src/cardio/cardiocontroller.cpp
    src/cardio/cardiocontroller.h
    src/gyms/gymmanagementcontroller.cpp
    src/gyms/gymmanagementcontroller.h
    src/history/workouthistorycontroller.cpp
    src/history/workouthistorycontroller.h
    src/plans/planmanagementcontroller.cpp
    src/plans/planmanagementcontroller.h
    src/timer/resttimercontroller.cpp
    src/timer/resttimercontroller.h
    src/timer/androidresttimerbridge.cpp
    src/timer/androidresttimerbridge.h
    src/training/workoutsessioncontroller.cpp
    src/training/workoutsessioncontroller.h
)
if(NOT ANDROID)
    list(APPEND FITTRACK_SERVICE_SOURCES
        src/timer/timeralertplayer.cpp
        src/timer/timeralertplayer.h
    )
endif()
add_library(fittrack_services STATIC ${FITTRACK_SERVICE_SOURCES})

target_include_directories(fittrack_services PUBLIC src)
target_link_libraries(fittrack_services PUBLIC fittrack_domain Qt6::Core Qt6::Sql)
if(NOT ANDROID)
    target_link_libraries(fittrack_services PUBLIC Qt6::Multimedia)
endif()

qt_add_executable(fittrack
    src/app/main.cpp
)

# MSYS2 Qt 6.9.1 qmlcachegen crashes on the root file after resolving the
# navigation page graph. Keep all pages cached and parse only Main.qml at runtime.
set_source_files_properties(qml/Main.qml PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties(qml/theme/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(fittrack
    URI FitTrack
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/theme/Theme.qml
        qml/components/ActionPill.qml
        qml/components/AppButton.qml
        qml/components/AppCard.qml
        qml/components/AppDialog.qml
        qml/components/AppPage.qml
        qml/components/ConfirmDialog.qml
        qml/components/AppIcon.qml
        qml/components/IconButton.qml
        qml/components/InlineFeedback.qml
        qml/components/NumberField.qml
        qml/components/RestTimerBar.qml
        qml/components/SectionHeader.qml
        qml/components/SetRow.qml
        qml/components/StatCard.qml
        qml/components/TrendChart.qml
        qml/components/WorkoutStartConflictDialog.qml
        qml/components/WorkoutRecoveryDialog.qml
        qml/components/ExerciseDetailSheet.qml
        qml/components/ExerciseParameterSheet.qml
        qml/components/ExercisePickerSheet.qml
        qml/components/ExerciseOrderSheet.qml
        qml/components/MuscleBars.qml
        qml/pages/HomePage.qml
        qml/pages/ExerciseLibraryPage.qml
        qml/pages/TrainingPage.qml
        qml/pages/HistoryPage.qml
        qml/pages/AnalysisPage.qml
        qml/pages/PlanPage.qml
        qml/pages/InsightsPage.qml
        qml/pages/CardioPage.qml
        qml/pages/ManagementPage.qml
        qml/pages/WorkoutPreparationPage.qml
    RESOURCES
        qml/theme/qmldir
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

file(GLOB SHAREABLE_ACTION_IMAGES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/resources/images/exercises/shareable/*"
)
add_library(fittrack_action_images STATIC)
qt_add_resources(fittrack_action_images "action_images"
    PREFIX "/"
    BASE "resources"
    FILES ${SHAREABLE_ACTION_IMAGES}
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

if(ANDROID)
    qt_add_android_permission(fittrack
        NAME android.permission.WRITE_EXTERNAL_STORAGE
        ATTRIBUTES maxSdkVersion 27
    )
    set_target_properties(fittrack PROPERTIES
        QT_ANDROID_PACKAGE_NAME "com.fittrack.app"
        QT_ANDROID_APP_NAME "训迹 FitTrack"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE 1
        QT_ANDROID_MIN_SDK_VERSION 28
        QT_ANDROID_TARGET_SDK_VERSION 35
        QT_ANDROID_COMPILE_SDK_VERSION 35
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
    )
endif()

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

install(TARGETS fittrack
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)
