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
