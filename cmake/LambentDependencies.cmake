# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# What Lambent builds from that is not in this repository, each pinned to one
# archive by version, URL and SHA-256: the phosphor-libs and phosphor-shell-libs
# commits it builds against, the phosphor-surface-packs commit whose decoration
# packs it installs, and the suite's branding release. This file is the
# only place these pins live. phosphor-libs pins its own third-party sources
# (Luau, jsoncons) in its cmake/PhosphorDependencies.cmake, at the commit pinned
# here.
#
# How each archive is obtained, in order:
#
#   1. PHOSPHOR_DEPS_ARCHIVES names a directory holding the archives under their
#      FILE names: these and phosphor-libs'. Each is checked against its SHA-256
#      and extracted into the build tree. Nothing is downloaded and CPM is never
#      loaded, so this is the path an offline packaging build takes.
#   2. PHOSPHOR_LIBS_GIT_REF or PHOSPHOR_SHELL_LIBS_GIT_REF names a branch, tag
#      or commit. CPM clones that library at that ref instead of its pinned
#      archive, for building against a library change before it is pinned.
#   3. Otherwise CPM.cmake (pinned by hash) downloads the pinned archive once
#      into CPM_SOURCE_CACHE, .cache/cpm at this repository's root unless the
#      cache variable or the environment variable says otherwise.
#
# CPM's own override applies to 2 and 3: -DCPM_phosphor-libs_SOURCE=<dir> and
# -DCPM_phosphor-shell-libs_SOURCE=<dir> build local checkouts, such as the
# siblings ../phosphor-libs and ../phosphor-shell-libs, in place of either.
#
# Script mode, for packagers and CI:
#
#   cmake -DPHOSPHOR_DEPS_FETCH=<dir> -P cmake/LambentDependencies.cmake
#
# downloads every archive the build needs into <dir> under its FILE name and
# checks it: the ones pinned here, then the ones the pinned phosphor-libs tree
# pins, so <dir> can be handed to PHOSPHOR_DEPS_ARCHIVES.
#
# Bumping a pin: change its VERSION, URL, FILE and SHA256 together, with the
# hash taken from a download you checked. Move phosphor-libs and
# phosphor-shell-libs together when the shell libraries need the newer
# phosphor-libs: this file's phosphor-libs pin is the one the shell libraries
# build against here, whatever their own pin says.

include_guard(GLOBAL)

# ─── Pins ────────────────────────────────────────────────────────────────────
set(LAMBENT_DEPS phosphor-libs phosphor-shell-libs phosphor-surface-packs branding)

# The phosphor-libs commit (LGPL-2.1-or-later, phosphor-works/phosphor-libs).
# A commit, not a release, so VERSION is the commit hash.
set(LAMBENT_DEP_phosphor-libs_VERSION "5f7ce79f4a1282d50f8936caa72dd7332545137c")
set(LAMBENT_DEP_phosphor-libs_URL "https://github.com/phosphor-works/phosphor-libs/archive/5f7ce79f4a1282d50f8936caa72dd7332545137c.tar.gz")
set(LAMBENT_DEP_phosphor-libs_FILE "phosphor-libs-5f7ce79f4a1282d50f8936caa72dd7332545137c.tar.gz")
set(LAMBENT_DEP_phosphor-libs_SHA256 "b44963ce30abfe91ff022d2d94f71bd9cc3c454c43660b94d4a75de72d933e0a")

# The phosphor-shell-libs commit (LGPL-2.1-or-later,
# phosphor-works/phosphor-shell-libs): the theme, popout and Phosphor.* surface
# libraries and the system service libraries the shell is built from. Added
# after phosphor-libs, so the phosphor-libs pin above is the one it uses.
set(LAMBENT_DEP_phosphor-shell-libs_VERSION "5bfa3764a070dc89c0cfa101023cd1522903f983")
set(LAMBENT_DEP_phosphor-shell-libs_URL "https://github.com/phosphor-works/phosphor-shell-libs/archive/5bfa3764a070dc89c0cfa101023cd1522903f983.tar.gz")
set(LAMBENT_DEP_phosphor-shell-libs_FILE "phosphor-shell-libs-5bfa3764a070dc89c0cfa101023cd1522903f983.tar.gz")
set(LAMBENT_DEP_phosphor-shell-libs_SHA256 "3f48d05a57b26c79f5a8b81ba1d0addae323f93af81949a03fcd3341dca50a8f")

# The phosphor-surface-packs commit (LGPL-2.1-or-later with some GPL-3.0-or-later
# shaders, phosphor-works/phosphor-surface-packs): the surface decoration packs
# the shell's chrome draws, installed from it with its
# cmake/PhosphorSurfacePacks.cmake. A commit, so VERSION is the commit hash.
set(LAMBENT_DEP_phosphor-surface-packs_VERSION "572e2240ef306d48650ed45ba6672af5ab31e75f")
set(LAMBENT_DEP_phosphor-surface-packs_URL "https://github.com/phosphor-works/phosphor-surface-packs/archive/572e2240ef306d48650ed45ba6672af5ab31e75f.tar.gz")
set(LAMBENT_DEP_phosphor-surface-packs_FILE "phosphor-surface-packs-572e2240ef306d48650ed45ba6672af5ab31e75f.tar.gz")
set(LAMBENT_DEP_phosphor-surface-packs_SHA256 "2fb063f95503dcca9b23c2905213940f1f4aa8701623f1020c695335dd90475e")

# The suite's branding release (CC-BY-SA-4.0, phosphor-works/branding): Lambent's
# icon, installed from it with its cmake/PhosphorBranding.cmake.
set(LAMBENT_DEP_branding_VERSION "0.3.1")
set(LAMBENT_DEP_branding_URL "https://github.com/phosphor-works/branding/releases/download/v0.3.1/phosphor-branding-0.3.1.tar.gz")
set(LAMBENT_DEP_branding_FILE "phosphor-branding-0.3.1.tar.gz")
set(LAMBENT_DEP_branding_SHA256 "d6ec9261d4391148f5c21dfb02be410214d42ea675f1558a826042d63f495094")

# CPM.cmake itself, the same release the libraries pin, so they use this copy.
set(LAMBENT_CPM_VERSION "0.43.2")
set(LAMBENT_CPM_SHA256 "49a3bef91ceb65bb66d57255e12d1ffd22abc2f6408fa9fe4534c544a2f232aa")

get_filename_component(_LAMBENT_DEPS_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

# _lambent_extract(<archive> <dest> <stamp>): <archive> unpacked into <dest> with
# its single top-level directory removed. The stamp is written after the
# extraction finishes, so one cut short is redone next time.
function(_lambent_extract archive dest stamp)
    if(EXISTS "${stamp}" AND IS_DIRECTORY "${dest}")
        return()
    endif()
    file(REMOVE_RECURSE "${dest}" "${dest}.tmp")
    file(ARCHIVE_EXTRACT INPUT "${archive}" DESTINATION "${dest}.tmp")
    file(GLOB _top LIST_DIRECTORIES true "${dest}.tmp/*")
    list(LENGTH _top _count)
    if(_count EQUAL 1 AND IS_DIRECTORY "${_top}")
        file(RENAME "${_top}" "${dest}")
        file(REMOVE_RECURSE "${dest}.tmp")
    else()
        file(RENAME "${dest}.tmp" "${dest}")
    endif()
    file(TOUCH "${stamp}")
endfunction()

# ─── Script mode: download every archive ─────────────────────────────────────
if(CMAKE_SCRIPT_MODE_FILE)
    if(NOT PHOSPHOR_DEPS_FETCH)
        message(FATAL_ERROR "usage: cmake -DPHOSPHOR_DEPS_FETCH=<dir> -P ${CMAKE_CURRENT_LIST_FILE}")
    endif()
    get_filename_component(_dir "${PHOSPHOR_DEPS_FETCH}" ABSOLUTE)
    file(MAKE_DIRECTORY "${_dir}")
    foreach(_name IN LISTS LAMBENT_DEPS)
        set(_file "${_dir}/${LAMBENT_DEP_${_name}_FILE}")
        set(_have "")
        if(EXISTS "${_file}")
            file(SHA256 "${_file}" _have)
        endif()
        if(NOT _have STREQUAL LAMBENT_DEP_${_name}_SHA256)
            message(STATUS "Downloading ${LAMBENT_DEP_${_name}_URL}")
            file(DOWNLOAD "${LAMBENT_DEP_${_name}_URL}" "${_file}.part"
                 EXPECTED_HASH SHA256=${LAMBENT_DEP_${_name}_SHA256} STATUS _status)
            list(GET _status 0 _code)
            if(NOT _code EQUAL 0)
                file(REMOVE "${_file}.part")
                list(GET _status 1 _why)
                message(FATAL_ERROR "Could not download ${LAMBENT_DEP_${_name}_URL}: ${_why}")
            endif()
            file(RENAME "${_file}.part" "${_file}")
        endif()
        message(STATUS "${LAMBENT_DEP_${_name}_FILE}: ok")
    endforeach()
    # phosphor-libs' own pins, read from the pinned tree itself, so this list
    # can never fall behind a phosphor-libs bump. phosphor-shell-libs pins
    # nothing besides phosphor-libs, whose pin here takes its place.
    set(_libs_tmp "${_dir}/.phosphor-libs-${LAMBENT_DEP_phosphor-libs_VERSION}")
    _lambent_extract("${_dir}/${LAMBENT_DEP_phosphor-libs_FILE}" "${_libs_tmp}" "${_libs_tmp}.stamp")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" "-DPHOSPHOR_DEPS_FETCH=${_dir}"
                -P "${_libs_tmp}/cmake/PhosphorDependencies.cmake"
        RESULT_VARIABLE _rc)
    file(REMOVE_RECURSE "${_libs_tmp}" "${_libs_tmp}.stamp")
    if(NOT _rc EQUAL 0)
        message(FATAL_ERROR "Fetching the archives phosphor-libs ${LAMBENT_DEP_phosphor-libs_VERSION} pins failed")
    endif()
    return()
endif()

# ─── Configure mode ──────────────────────────────────────────────────────────
set(PHOSPHOR_DEPS_ARCHIVES "" CACHE PATH
    "Directory holding the pinned dependency archives (cmake/LambentDependencies.cmake), for an offline build. Empty: download them with CPM")
set(PHOSPHOR_LIBS_GIT_REF "" CACHE STRING
    "Build phosphor-libs from this git branch, tag or commit instead of the pinned archive. Empty: the pin")
set(PHOSPHOR_SHELL_LIBS_GIT_REF "" CACHE STRING
    "Build phosphor-shell-libs from this git branch, tag or commit instead of the pinned archive. Empty: the pin")

# CPM.cmake, loaded at the including directory's scope rather than from inside
# a function: CPM keeps part of its state in ordinary variables of the scope
# that includes it. Not loaded at all for an offline build. The cached copy is
# checked against its hash on every configure, so a broken-off download left in
# the cache is replaced rather than included.
if(NOT PHOSPHOR_DEPS_ARCHIVES AND NOT COMMAND CPMAddPackage)
    if(NOT DEFINED CPM_SOURCE_CACHE AND NOT DEFINED ENV{CPM_SOURCE_CACHE})
        set(CPM_SOURCE_CACHE "${_LAMBENT_DEPS_ROOT}/.cache/cpm" CACHE PATH
            "Where CPM.cmake keeps downloaded packages, shared by every build directory")
    endif()
    if(DEFINED CPM_SOURCE_CACHE)
        set(_lambent_cpm_file "${CPM_SOURCE_CACHE}/cpm/CPM_${LAMBENT_CPM_VERSION}.cmake")
    else()
        set(_lambent_cpm_file "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${LAMBENT_CPM_VERSION}.cmake")
    endif()
    set(_lambent_cpm_have "")
    if(EXISTS "${_lambent_cpm_file}")
        file(SHA256 "${_lambent_cpm_file}" _lambent_cpm_have)
    endif()
    if(NOT _lambent_cpm_have STREQUAL LAMBENT_CPM_SHA256)
        file(DOWNLOAD
            "https://github.com/cpm-cmake/CPM.cmake/releases/download/v${LAMBENT_CPM_VERSION}/CPM.cmake"
            "${_lambent_cpm_file}.part" EXPECTED_HASH SHA256=${LAMBENT_CPM_SHA256} STATUS _lambent_cpm_status)
        list(GET _lambent_cpm_status 0 _lambent_cpm_code)
        if(NOT _lambent_cpm_code EQUAL 0)
            file(REMOVE "${_lambent_cpm_file}.part")
            message(FATAL_ERROR
                "Could not download CPM.cmake (${_lambent_cpm_status}). Configure with network access once, "
                "or pass -DPHOSPHOR_DEPS_ARCHIVES=<dir> with the archives cmake/LambentDependencies.cmake pins.")
        endif()
        file(RENAME "${_lambent_cpm_file}.part" "${_lambent_cpm_file}")
    endif()
    include("${_lambent_cpm_file}")
endif()

# lambent_fetch_dependency(<name>)
#
# Makes the pinned archive <name> (one of LAMBENT_DEPS) available and sets
# <name>_SOURCE_DIR in the caller's scope to its unpacked tree. Only fetches the
# source. What to build from it is the caller's business.
function(lambent_fetch_dependency name)
    if(NOT name IN_LIST LAMBENT_DEPS)
        message(FATAL_ERROR "lambent_fetch_dependency: '${name}' is not pinned in ${CMAKE_CURRENT_FUNCTION_LIST_FILE}")
    endif()
    set(_version "${LAMBENT_DEP_${name}_VERSION}")
    set(_sha "${LAMBENT_DEP_${name}_SHA256}")
    if(PHOSPHOR_DEPS_ARCHIVES)
        set(_archive "${PHOSPHOR_DEPS_ARCHIVES}/${LAMBENT_DEP_${name}_FILE}")
        if(NOT EXISTS "${_archive}")
            message(FATAL_ERROR
                "PHOSPHOR_DEPS_ARCHIVES is ${PHOSPHOR_DEPS_ARCHIVES}, which has no ${LAMBENT_DEP_${name}_FILE}. "
                "Fill it with cmake -DPHOSPHOR_DEPS_FETCH=<dir> -P cmake/LambentDependencies.cmake")
        endif()
        file(SHA256 "${_archive}" _have)
        if(NOT _have STREQUAL _sha)
            message(FATAL_ERROR "${_archive} does not match its pin:\n  expected ${_sha}\n  got      ${_have}")
        endif()
        set(_root "${CMAKE_BINARY_DIR}/_phosphor_deps")
        set(_dest "${_root}/${name}-${_version}")
        _lambent_extract("${_archive}" "${_dest}" "${_root}/.${name}-${_version}-${_sha}")
        set(${name}_SOURCE_DIR "${_dest}" PARENT_SCOPE)
        return()
    endif()
    CPMAddPackage(NAME ${name}
                  URL "${LAMBENT_DEP_${name}_URL}"
                  URL_HASH SHA256=${_sha}
                  DOWNLOAD_ONLY YES)
    set(${name}_SOURCE_DIR "${${name}_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

# _lambent_add_library_tree(<name> <git ref>): adds the pinned <name> tree as a
# subproject. A macro, so CPM sets <name>_SOURCE_DIR and <name>_BINARY_DIR in the
# caller's scope.
macro(_lambent_add_library_tree name ref)
    if(PHOSPHOR_DEPS_ARCHIVES)
        lambent_fetch_dependency(${name})
        set(${name}_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps/${name}-build")
        add_subdirectory("${${name}_SOURCE_DIR}" "${${name}_BINARY_DIR}")
    elseif(ref)
        CPMAddPackage(NAME ${name}
                      GIT_REPOSITORY "https://github.com/phosphor-works/${name}.git"
                      GIT_TAG "${ref}"
                      GIT_SHALLOW NO)
    else()
        CPMAddPackage(NAME ${name}
                      URL "${LAMBENT_DEP_${name}_URL}"
                      URL_HASH SHA256=${LAMBENT_DEP_${name}_SHA256})
    endif()
endmacro()

# lambent_add_phosphor_libraries()
#
# Adds phosphor-libs, then phosphor-shell-libs, as subprojects, so every
# find_package and target_link_libraries call for a Phosphor library resolves
# to their targets. phosphor-shell-libs finds phosphor-libs already added and
# uses it. Leaves phosphor-libs_SOURCE_DIR, phosphor-shell-libs_SOURCE_DIR and
# their _BINARY_DIR set in the caller's scope, and the library tree's helper
# modules (PhosphorTestIsolation, PhosphorTestPch) on CMAKE_MODULE_PATH. Call it
# from the top-level CMakeLists, once ECM, Qt and the compile definitions every
# library must share are set up.
macro(lambent_add_phosphor_libraries)
    _lambent_add_library_tree(phosphor-libs "${PHOSPHOR_LIBS_GIT_REF}")
    if(NOT TARGET PhosphorIpc)
        message(FATAL_ERROR "phosphor-libs at ${phosphor-libs_SOURCE_DIR} declared no PhosphorIpc target")
    endif()
    _lambent_add_library_tree(phosphor-shell-libs "${PHOSPHOR_SHELL_LIBS_GIT_REF}")
    if(NOT TARGET PhosphorShell)
        message(FATAL_ERROR "phosphor-shell-libs at ${phosphor-shell-libs_SOURCE_DIR} declared no PhosphorShell target")
    endif()
    list(APPEND CMAKE_MODULE_PATH "${PHOSPHOR_LIBS_CMAKE_DIR}")
endmacro()
