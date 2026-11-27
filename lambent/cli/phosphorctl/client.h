// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QJsonObject>
#include <QLatin1StringView>
#include <QLocalSocket>
#include <QObject>
#include <QString>
#include <QtCore/qtclasshelpermacros.h>

#include <functional>
#include <optional>

namespace Phosphorctl {

// Single-shot QLocalSocket wrapper that speaks the phosphor-ipc
// wire protocol (NDJSON, line-framed). Synchronous request/response:
// connect, send one request line, wait for one response line, close.
// Streaming subscribe lives on a longer-lived API path; see
// SubscribeClient in subcommand_subscribe.cpp.
//
// Each app has its own socket (phosphor-ipc's IpcRouter::socketPathForApp).
// The socket path comes from, in this order:
//   1. --socket <path>.
//   2. The variable <APP>_SOCKET of the app that --app selects
//      (LAMBENT_SOCKET for --app lambent).
//   3. $XDG_RUNTIME_DIR/<app>.sock. The compositor (app "phosphor", the
//      default) has one socket for each instance instead:
//      $XDG_RUNTIME_DIR/phosphor.<display>.sock, with <display> from
//      $WAYLAND_DISPLAY. It exports the path as PHOSPHOR_SOCKET.
//
// Exit-code semantics live on the subcommand handlers; Client just
// reports success/failure + optional error message.
class Client : public QObject
{
    Q_OBJECT
public:
    explicit Client(QObject* parent = nullptr);
    Q_DISABLE_COPY_MOVE(Client)

    // The app that phosphorctl talks to without --app: the compositor.
    static constexpr QLatin1StringView DefaultApp{"phosphor"};

    // Lower-case ASCII letters, digits and '-', starting with a letter,
    // as phosphor-ipc takes an app name.
    [[nodiscard]] static bool isAppName(const QString& app);

    // Resolve the socket path per the rule above. Empty cliArg means
    // "no --socket flag supplied". Returns empty when no source gives
    // a path (process logs and exits with code 2 in that case).
    [[nodiscard]] static QString resolveSocketPath(const QString& cliArg, const QString& app);

    // Connect to socketPath. Returns false on failure (timeout,
    // refused). errorMessage populated. Aborts any prior open
    // socket first so retry-after-failure paths don't leak a
    // half-open connection.
    [[nodiscard]] bool connectTo(const QString& socketPath, int timeoutMs = 2000);

    // Send a request, await a single response line with a matching
    // `id`. Frames whose id doesn't match (e.g. a stray event from
    // an unrelated subscription on the same connection) are NOT
    // discarded; they stay in the internal read buffer so the
    // streaming-subscribe path can recover them via takePendingBytes.
    // Without that handoff a server that broadcasts an event in the
    // same readyRead burst as the subscribe ack would silently drop
    // that first event. Returns the parsed response object, or
    // std::nullopt on read timeout / disconnect / parse error.
    // errorMessage populated on failure. A timeoutMs of 0 waits for the
    // response without a deadline (a deferred call answers when its work
    // ends). With `onEvent` set, event frames that arrive before the
    // response go to it as they come, and are not kept for
    // takePendingBytes; those that arrive with the response, after it,
    // are kept either way.
    [[nodiscard]] std::optional<QJsonObject> request(const QJsonObject& req, int timeoutMs = 2000,
                                                     const std::function<void(const QJsonObject&)>& onEvent = {});

    [[nodiscard]] QString errorMessage() const;

    // Expose the underlying socket for the streaming-subscribe
    // path; ownership stays with Client.
    [[nodiscard]] QLocalSocket* socket();

    // Return any leftover read-buffer bytes that arrived AFTER the
    // matching response for the most recent request() but before
    // request() returned. The subscribe loop prepends these to its
    // own buffer so events that piggy-backed onto the subscribe
    // ack's readyRead are recovered cleanly. Clears the internal
    // buffer as a side effect, call exactly once at the seam
    // between request() and the streaming reader.
    [[nodiscard]] QByteArray takePendingBytes();

private:
    QLocalSocket m_socket;
    QByteArray m_readBuffer;
    QString m_errorMessage;
};

} // namespace Phosphorctl
