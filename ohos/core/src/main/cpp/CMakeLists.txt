cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")


if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

set(LIB_CLASH_PATH "${CMAKE_SOURCE_DIR}/../../../libs/${OHOS_ARCH}/libclash.so")
set(LIB_CLASH_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../cpp/includes/${OHOS_ARCH}")
set(LIB_CLASH_HEADER_PATH "${LIB_CLASH_INCLUDE_DIR}/libclash.h")
set(BRIDE_HEADER_PATH "${LIB_CLASH_INCLUDE_DIR}/bride.h")

message("LIB_CLASH_PATH ${LIB_CLASH_PATH}")
if (EXISTS ${LIB_CLASH_PATH} AND EXISTS ${LIB_CLASH_HEADER_PATH} AND EXISTS ${BRIDE_HEADER_PATH})
    message("Found libclash.so and headers for ABI ${OHOS_ARCH}")
    add_compile_definitions(LIBCLASH)
    include_directories(${LIB_CLASH_INCLUDE_DIR})
    link_directories(${CMAKE_SOURCE_DIR}/../../../libs/${OHOS_ARCH})
    add_library(${CMAKE_PROJECT_NAME} SHARED
            napi_init.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME}
            libace_napi.z.so
            clash)
else ()
    message("Not found complete libclash output for ABI ${OHOS_ARCH}; building core without LIBCLASH")
    add_library(${CMAKE_PROJECT_NAME} SHARED
            napi_init.cpp)
    target_link_libraries(${CMAKE_PROJECT_NAME})
endif ()
