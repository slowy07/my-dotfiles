cmake_minimum_required(VERSION 3.16)
project(GlyphTideIsland LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network DBus Concurrent Test)
find_library(UDEV_LIB NAMES udev REQUIRED)

qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend
    SOURCES
        backend/SysBackend.h backend/SysBackend.cpp
        backend/SystemServices.h backend/SystemServices.cpp
        backend/SystemStats.h backend/SystemStats.cpp
        backend/CompositorBackend.h backend/CompositorBackend.cpp
        backend/StyleTokensBackend.h backend/StyleTokensBackend.cpp
        backend/FileShelfModel.h backend/FileShelfModel.cpp
        backend/UserConfigBackend.h backend/UserConfigBackend.cpp
        backend/BluetoothPairingAgent.h backend/BluetoothPairingAgent.cpp
        backend/WifiController.h backend/WifiController.cpp
        backend/WifiNetworkModel.h backend/WifiNetworkModel.cpp
)

set_target_properties(IslandBackendplugin PROPERTIES
    INSTALL_RPATH "\$ORIGIN/../../.."
)

target_include_directories(IslandBackend PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)

target_compile_definitions(IslandBackend PRIVATE
    TIDE_ISLAND_WITH_NIRI=OFF
)

target_link_libraries(IslandBackend PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
    Qt6::DBus
    Qt6::Concurrent
    ${UDEV_LIB}
)

enable_testing()
add_executable(style_tokens_check
    backend/tests/style_tokens_check.cpp
    backend/StyleTokensBackend.cpp
)
target_include_directories(style_tokens_check PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)
target_link_libraries(style_tokens_check PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Test
)
add_test(NAME style_tokens COMMAND style_tokens_check)

include(GNUInstallDirs)

install(TARGETS IslandBackend
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(TARGETS IslandBackendplugin
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/IslandBackend.qmltypes
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
)
