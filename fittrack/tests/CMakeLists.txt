qt_add_executable(tst_traininganalytics
    unit/tst_traininganalytics.cpp
)

target_link_libraries(tst_traininganalytics PRIVATE
    fittrack_domain
    Qt6::Test
)

add_test(NAME traininganalytics COMMAND tst_traininganalytics)

qt_add_executable(tst_databasemanager
    integration/tst_databasemanager.cpp
)

target_link_libraries(tst_databasemanager PRIVATE
    fittrack_storage
    Qt6::Sql
    Qt6::Test
)

add_test(NAME databasemanager COMMAND tst_databasemanager)

qt_add_executable(tst_exerciseseedimporter
    integration/tst_exerciseseedimporter.cpp
)

target_link_libraries(tst_exerciseseedimporter PRIVATE
    fittrack_storage
    Qt6::Sql
    Qt6::Test
)

target_compile_definitions(tst_exerciseseedimporter PRIVATE
    FITTRACK_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

add_test(NAME exerciseseedimporter COMMAND tst_exerciseseedimporter)

qt_add_executable(tst_planseedimporter
    integration/tst_planseedimporter.cpp
)

target_compile_definitions(tst_planseedimporter PRIVATE
    FITTRACK_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

target_link_libraries(tst_planseedimporter PRIVATE
    fittrack_storage
    Qt6::Sql
    Qt6::Test
)

add_test(NAME planseedimporter COMMAND tst_planseedimporter)

qt_add_executable(tst_exerciselistmodel
    integration/tst_exerciselistmodel.cpp
)

target_compile_definitions(tst_exerciselistmodel PRIVATE
    FITTRACK_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
)

target_link_libraries(tst_exerciselistmodel PRIVATE
    fittrack_storage
    fittrack_ui_models
    Qt6::Sql
    Qt6::Test
)

add_test(NAME exerciselistmodel COMMAND tst_exerciselistmodel)

qt_add_executable(tst_resttimercontroller
    unit/tst_resttimercontroller.cpp
)

target_link_libraries(tst_resttimercontroller PRIVATE
    fittrack_services
    Qt6::Test
)

add_test(NAME resttimercontroller COMMAND tst_resttimercontroller)

qt_add_executable(tst_workoutsessioncontroller
    integration/tst_workoutsessioncontroller.cpp
)

target_link_libraries(tst_workoutsessioncontroller PRIVATE
    fittrack_storage
    fittrack_services
    Qt6::Sql
    Qt6::Test
)

add_test(NAME workoutsessioncontroller COMMAND tst_workoutsessioncontroller)

qt_add_executable(tst_workouthistorycontroller
    integration/tst_workouthistorycontroller.cpp
)

target_link_libraries(tst_workouthistorycontroller PRIVATE
    fittrack_storage
    fittrack_services
    Qt6::Sql
    Qt6::Test
)

add_test(NAME workouthistorycontroller COMMAND tst_workouthistorycontroller)

qt_add_executable(tst_analyticsdashboardcontroller
    integration/tst_analyticsdashboardcontroller.cpp
)

target_link_libraries(tst_analyticsdashboardcontroller PRIVATE
    fittrack_storage
    fittrack_services
    Qt6::Sql
    Qt6::Test
)

add_test(NAME analyticsdashboardcontroller COMMAND tst_analyticsdashboardcontroller)

qt_add_executable(tst_planmanagementcontroller
    integration/tst_planmanagementcontroller.cpp
)

target_link_libraries(tst_planmanagementcontroller PRIVATE
    fittrack_storage
    fittrack_services
    Qt6::Sql
    Qt6::Test
)

add_test(NAME planmanagementcontroller COMMAND tst_planmanagementcontroller)

qt_add_executable(tst_cardiocontroller
    integration/tst_cardiocontroller.cpp
)
target_link_libraries(tst_cardiocontroller PRIVATE fittrack_storage fittrack_services Qt6::Sql Qt6::Test)
add_test(NAME cardiocontroller COMMAND tst_cardiocontroller)

qt_add_executable(tst_gymmanagementcontroller
    integration/tst_gymmanagementcontroller.cpp
)
target_link_libraries(tst_gymmanagementcontroller PRIVATE fittrack_storage fittrack_services Qt6::Sql Qt6::Test)
add_test(NAME gymmanagementcontroller COMMAND tst_gymmanagementcontroller)

qt_add_executable(tst_backupservice
    integration/tst_backupservice.cpp
)
target_link_libraries(tst_backupservice PRIVATE fittrack_storage fittrack_services Qt6::Sql Qt6::Test)
add_test(NAME backupservice COMMAND tst_backupservice)

qt_add_executable(tst_qmlnavigation
    integration/tst_qmlnavigation.cpp
)

target_compile_definitions(tst_qmlnavigation PRIVATE
    FITTRACK_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
    FITTRACK_SCREENSHOT_DIR="${CMAKE_BINARY_DIR}/visual"
)

target_link_libraries(tst_qmlnavigation PRIVATE
    fittrack_action_images
    fittrack_storage
    fittrack_services
    fittrack_ui_models
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Test
)

add_test(NAME qmlnavigation COMMAND tst_qmlnavigation)
