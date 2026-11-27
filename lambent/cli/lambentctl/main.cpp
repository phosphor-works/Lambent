// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later

// lambentctl: the command-line client of Lambent's IPC socket, $LAMBENT_SOCKET
// or $XDG_RUNTIME_DIR/lambent.sock. Compositor binds run it, for example
// `lambentctl call launcher.toggle`.

#include <PhosphorIpcCli/PhosphorIpcCli.h>

int main(int argc, char** argv)
{
    return PhosphorIpcCli::run(PhosphorIpcCli::programForApp(QStringLiteral("lambentctl"), QStringLiteral("lambent"),
                                                             QStringLiteral(LAMBENT_VERSION),
                                                             QStringLiteral("Controls a running Lambent shell.")),
                               argc, argv);
}
