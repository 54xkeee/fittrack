cmake_minimum_required(VERSION 3.21)

project(FitTrack VERSION 0.1.0 LANGUAGES CXX)

if(ANDROID AND NOT DEFINED BUILD_TESTING)
    set(BUILD_TESTING OFF CACHE BOOL "Build FitTrack tests" FORCE)
endif()
include(CTest)

option(FITTRACK_ENABLE_REACT_WEBENGINE
    "Render the active workout with the bundled React UI in Qt WebEngine"
    OFF)
option(FITTRACK_ENABLE_REACT_ANDROID_WEBVIEW
    "EXPERIMENTAL: render the active workout with the bundled React UI in Android WebView"
    OFF)
if(FITTRACK_ENABLE_REACT_WEBENGINE AND ANDROID)
    message(FATAL_ERROR
        "Qt WebEngine is desktop-only. Keep this option OFF for Android and use the native Android WebView integration path.")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

set(FITTRACK_QT_COMPONENTS Core Gui Qml Quick QuickControls2 Sql)
if(FITTRACK_ENABLE_REACT_WEBENGINE)
    list(APPEND FITTRACK_QT_COMPONENTS WebChannel WebEngineQuick)
endif()
if(NOT ANDROID)
    list(APPEND FITTRACK_QT_COMPONENTS Multimedia)
endif()
find_package(Qt6 6.11.1 REQUIRED COMPONENTS ${FITTRACK_QT_COMPONENTS})
if(BUILD_TESTING)
    find_package(Qt6 6.11.1 REQUIRED COMPONENTS Test)
    find_package(SQLite3 REQUIRED)
endif()

qt_standard_project_setup(REQUIRES 6.11.1)

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

if(ANDROID AND FITTRACK_ENABLE_REACT_ANDROID_WEBVIEW)
    message(WARNING
        "The Android React WebView workout renderer is experimental and is not part of the production training flow.")
    target_sources(fittrack PRIVATE
        src/app/androidreactbridge.cpp
        src/app/androidreactbridge.h
    )
    target_compile_definitions(fittrack PRIVATE FITTRACK_REACT_ANDROID_WEBVIEW=1)
endif()

# Caching the root navigation graph makes the Qt 6.11.1 MinGW link step emit
# a nested temporary response file that GNU ld cannot consume on Windows.
# Keep the smaller pages cached and parse only Main.qml at runtime.
set_source_files_properties(qml/Main.qml PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties(qml/theme/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/theme/Typography.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/theme/Preferences.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/theme/WorkoutTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(fittrack
    URI FitTrack
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/theme/Theme.qml
        qml/theme/Typography.qml
        qml/theme/Preferences.qml
        qml/theme/WorkoutTheme.qml
        qml/components/ActionPill.qml
        qml/components/AppButton.qml
        qml/components/AppCheckBox.qml
        qml/components/AppComboBox.qml
        qml/components/AppCard.qml
        qml/components/AppDialog.qml
        qml/components/AppEmptyState.qml
        qml/components/AppPage.qml
        qml/components/AppSwitch.qml
        qml/components/ConfirmDialog.qml
        qml/components/AppIcon.qml
        qml/components/IconButton.qml
        qml/components/InlineFeedback.qml
        qml/components/NumberField.qml
        qml/components/RestTimerBar.qml
        qml/components/CurrentSetInputPanel.qml
        qml/components/TrainingRestTimer.qml
        qml/components/EquipmentChoiceDialog.qml
        qml/components/SectionHeader.qml
        qml/components/SetRow.qml
        qml/components/StatCard.qml
        qml/components/TrendChart.qml
        qml/components/WorkoutStartConflictDialog.qml
        qml/components/WorkoutRecoveryDialog.qml
        qml/components/WorkoutTopBar.qml
        qml/components/WorkoutSummaryBar.qml
        qml/components/ExerciseCard.qml
        qml/components/ExerciseHeader.qml
        qml/components/ExerciseMetaRow.qml
        qml/components/NextExercisePreview.qml
        qml/components/RestTimerRow.qml
        qml/components/SetTableHeader.qml
        qml/components/WorkoutSetRow.qml
        qml/components/AddSetButton.qml
        qml/components/WorkoutCalendar.qml
        qml/components/ExerciseDetailSheet.qml
        qml/components/ExerciseParameterSheet.qml
        qml/components/ExercisePickerSheet.qml
        qml/components/ExerciseOrderSheet.qml
        qml/components/MuscleBars.qml
        qml/pages/HomePage.qml
        qml/pages/ExerciseLibraryPage.qml
        qml/pages/TrainingPage.qml
        qml/pages/ReactTrainingPage.qml
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

if(FITTRACK_ENABLE_REACT_WEBENGINE)
    set(FITTRACK_REACT_DIST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/frontend/dist")
    if(NOT EXISTS "${FITTRACK_REACT_DIST_DIR}/index.html")
        message(FATAL_ERROR
            "React bundle missing. Run `npm install` and `npm run build` in fittrack/frontend first.")
    endif()

    file(GLOB_RECURSE FITTRACK_REACT_WEB_FILES CONFIGURE_DEPENDS
        "${FITTRACK_REACT_DIST_DIR}/*")
    qt_add_resources(fittrack "fittrack_react_web"
        PREFIX "/web"
        BASE "${FITTRACK_REACT_DIST_DIR}"
        FILES ${FITTRACK_REACT_WEB_FILES}
    )
    qt_add_resources(fittrack "fittrack_react_surface"
        PREFIX "/hybrid"
        BASE "${CMAKE_CURRENT_SOURCE_DIR}/qml/hybrid"
        FILES "${CMAKE_CURRENT_SOURCE_DIR}/qml/hybrid/ReactWebSurface.qml"
    )
    target_compile_definitions(fittrack PRIVATE FITTRACK_REACT_WEBENGINE=1)
    target_link_libraries(fittrack PRIVATE Qt6::WebChannel Qt6::WebEngineQuick)
endif()

if(ANDROID)
    set(FITTRACK_ANDROID_VERSION_CODE "1" CACHE STRING
        "Android versionCode used for APK and AAB builds")
    qt_add_android_permission(fittrack
        NAME android.permission.WRITE_EXTERNAL_STORAGE
        ATTRIBUTES maxSdkVersion 27
    )
    set_target_properties(fittrack PROPERTIES
        QT_ANDROID_PACKAGE_NAME "com.xuke.fittrack"
        QT_ANDROID_APP_NAME "训迹"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE "${FITTRACK_ANDROID_VERSION_CODE}"
        QT_ANDROID_MIN_SDK_VERSION 29
        QT_ANDROID_TARGET_SDK_VERSION 36
        QT_ANDROID_COMPILE_SDK_VERSION 36
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
