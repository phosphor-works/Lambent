# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Lambent: a QML desktop shell for Wayland. This file sets up the toolchain, Qt,
# KDE's CMake modules and the Phosphor libraries; the application itself (the
# lambent binary, the phosphorctl IPC CLI, the bundled shell QML tree and the
# tests) is in lambent/.
#
# Built on phosphor-libs and phosphor-shell-libs, from the commits
# cmake/LambentDependencies.cmake pins, added with CPM as subprojects.
# -DCPM_phosphor-libs_SOURCE=<dir> and -DCPM_phosphor-shell-libs_SOURCE=<dir>
# build local checkouts of them instead.

# 3.23: the phosphor-libs tree added below asks for it (target_sources with
# FILE_SET). The presets (CMakePresets.json) need 3.25.
cmake_minimum_required(VERSION 3.23)

project(Lambent VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC_PARALLEL_ENABLED ON)

# As the top-level project the unity switch is the CMAKE_UNITY_BUILD cache entry
# (-DCMAKE_UNITY_BUILD=OFF for a non-unity build). Inside a superbuild a cache
# entry would reach every project in the tree, including third-party code that
# does not build as unity, so there the switch is LAMBENT_UNITY_BUILD and the
# setting is a directory variable: this tree and the libraries it adds only.
if(PROJECT_IS_TOP_LEVEL)
    option(CMAKE_UNITY_BUILD "Enable unity builds for faster compilation" ON)
    set(CMAKE_UNITY_BUILD_BATCH_SIZE 16 CACHE STRING "Number of sources per unity batch")
else()
    option(LAMBENT_UNITY_BUILD "Build Lambent and the libraries it adds as unity builds" ON)
    set(CMAKE_UNITY_BUILD ${LAMBENT_UNITY_BUILD})
    set(CMAKE_UNITY_BUILD_BATCH_SIZE 16)
endif()
option(ENABLE_PCH "Share one precompiled header across the test targets" ON)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

set(QT_MIN_VERSION "6.10.0")
set(KF_MIN_VERSION "6.26.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

# Must come before KDECMakeSettings, which includes CTest and locks
# BUILD_TESTING into the cache as ON.
option(BUILD_TESTING "Build the test suite" OFF)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

# Makes the Qt6 string-literal rule a compile error rather than a convention:
# no implicit const char* to QString.
add_compile_definitions(QT_NO_CAST_FROM_ASCII)

include(KDEClangFormat)
file(GLOB_RECURSE LAMBENT_CLANG_FORMAT_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/cli/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/cli/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/tests/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/lambent/tests/*.h
)
kde_clang_format(${LAMBENT_CLANG_FORMAT_FILES})

# The shell draws its icons through Kirigami and has no Qt-only fallback.
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS Kirigami)

# The Qt lookups every library and the shell share, at this scope before the
# libraries are added: an IMPORTED target belongs to the directory that found
# it, so targets found inside a library subproject (Qt's private modules, XKB
# through GuiPrivate) would be invisible here, and Qt's QML plugin dependency
# walk warns for each one.
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Concurrent
    Core
    DBus
    Gui
    Qml
    Quick
    QuickControls2
    ShaderTools
    Svg
    WaylandClient
    Widgets
)
if(QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()
if(QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()
foreach(_lambent_private GuiPrivate ShaderToolsPrivate QuickPrivate WaylandClientPrivate)
    if(NOT TARGET Qt6::${_lambent_private})
        find_package(Qt6${_lambent_private} CONFIG REQUIRED)
    endif()
endforeach()

# ═══════════════════════════════════════════════════════════════════════════════
# The Phosphor libraries
# ═══════════════════════════════════════════════════════════════════════════════

include(cmake/LambentDependencies.cmake)
# The surface decoration packs, fetched BEFORE the libraries: phosphor-libs
# fetches its own pinned copy for its tests unless an app has already set
# PHOSPHOR_SURFACE_PACKS_DIR, and CPM keeps the first copy declared, so
# fetching them after the libraries let phosphor-libs' pin decide the packs
# Lambent compiles and installs.
lambent_fetch_dependency(phosphor-surface-packs)
include(${phosphor-surface-packs_SOURCE_DIR}/cmake/PhosphorSurfacePacks.cmake)
lambent_add_phosphor_libraries()

# Where Lambent's files live: its own folder inside the suite folder every
# Phosphor app shares, in each XDG root. phosphor-libs names the suite folder
# (PHOSPHOR_SUITE_DIRECTORY_NAME); Lambent's own name is set here once and
# reaches the code through the generated version.h.
include("${PHOSPHOR_LIBS_CMAKE_DIR}/PhosphorSuite.cmake")
set(LAMBENT_APP_DIRECTORY_NAME "lambent")

# ═══════════════════════════════════════════════════════════════════════════════
# The application
# ═══════════════════════════════════════════════════════════════════════════════

add_subdirectory(lambent)  # lambent, phosphorctl, the bundled shell tree, desktop integration, tests

# ═══════════════════════════════════════════════════════════════════════════════
# Finish
# ═══════════════════════════════════════════════════════════════════════════════

# The shared test PCH covers every test target in this tree and the library
# trees it adds (cmake/PhosphorTestPch.cmake). Also inside a superbuild, where
# each app makes its own call so the PCH has its flags.
if(BUILD_TESTING AND ENABLE_PCH)
    include(PhosphorTestPch)
    phosphor_share_test_pch()
endif()

feature_summary(WHAT REQUIRED_PACKAGES_FOUND REQUIRED_PACKAGES_NOT_FOUND
                     OPTIONAL_PACKAGES_FOUND OPTIONAL_PACKAGES_NOT_FOUND
                FATAL_ON_MISSING_REQUIRED_PACKAGES)
