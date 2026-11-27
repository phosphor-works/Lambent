# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# lambentctl, the command-line client of Lambent's IPC socket. The client is
# phosphor-ipc's PhosphorIpcCli: this program only names Lambent and its
# socket. It links QtCore and QtNetwork, not the QML stack of lambent, so a
# compositor bind that runs it starts fast.

add_executable(lambentctl main.cpp)

target_link_libraries(lambentctl
    PRIVATE
        PhosphorIpc::PhosphorIpcCli
        Qt6::Core
)

target_compile_features(lambentctl PRIVATE cxx_std_20)
target_compile_definitions(lambentctl PRIVATE LAMBENT_VERSION="${PROJECT_VERSION}")

if(NOT DEFINED KDE_INSTALL_BINDIR)
    include(GNUInstallDirs)
    set(KDE_INSTALL_BINDIR ${CMAKE_INSTALL_BINDIR})
endif()

install(TARGETS lambentctl
    RUNTIME DESTINATION ${KDE_INSTALL_BINDIR}
)
# The embedded Phosphor libraries that it links are installed with it.
phosphor_install_embedded(FOR lambentctl)
