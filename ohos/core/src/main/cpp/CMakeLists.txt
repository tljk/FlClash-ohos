cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")


if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections)
endif ()

set(LIB_CLASH_PATH "${CMAKE_SOURCE_DIR}/../../../libs/${OHOS_ARCH}/libclash.so")
set(LIB_CLASH_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../cpp/includes/${OHOS_ARCH}")

include_directories(${LIB_CLASH_INCLUDE_DIR})
link_directories(${CMAKE_SOURCE_DIR}/../../../libs/${OHOS_ARCH})
add_library(${CMAKE_PROJECT_NAME} SHARED
        core.cpp)
target_link_libraries(${CMAKE_PROJECT_NAME}
        libace_napi.z.so
        clash)
