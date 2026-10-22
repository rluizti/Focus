cmake_minimum_required(VERSION 3.16)
project(omabridge CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Qt6 COMPONENTS Core Gui Quick WebEngineQuick REQUIRED)

add_library(omabridge STATIC
    src/bridge/bridge.cpp
    src/bridge/bridge.h
)

target_include_directories(omabridge PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src/bridge
)

target_link_libraries(omabridge PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::WebEngineQuick
)
