# Socket Mode

Socket Mode sends events, interactions, and slash commands over a WebSocket instead of to a public HTTP endpoint. `Slack::SocketMode::Client` keeps the connection open. The frame and acknowledgment types below also work without the client. See the [Slack guide](https://docs.slack.dev/apis/events-api/using-socket-mode).

## Client

Give the client an app-level token (`xapp-`). `run` calls the block on a new fiber for each envelope. Call `ack.ack` once for each envelope, within three seconds.

```crystal
client = Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])
client.run do |envelope, ack|
  case envelope.kind
  in .slash_commands?
    command = Slack::Decoder.default.command(envelope.payload_json, :json)
    ack.ack(Slack::Commands::Response.new(text: "Deploying #{command.text}"))
  in .events_api?, .interactive?, .unknown?
    ack.ack
  end
end
```

`Acknowledger#ack` raises `Slack::SocketMode::AcknowledgmentError` when:

- the envelope is already acknowledged,
- you give a payload and `accepts_response_payload?` is false, or
- the client has stopped.

If the block raises, the client logs the exception class and does not acknowledge the envelope. Slack can then send it again.

### Connection lifecycle

1. The client calls [`apps.connections.open`](https://docs.slack.dev/reference/methods/apps.connections.open) (`Slack::Api::AppsConnectionsOpen`, Tier 3) and connects to the returned URL. Each URL is for one connection.
2. On a `disconnect` frame with `warning`, `refresh_requested`, or an unknown reason, the client opens a new connection first, then closes the old one.
3. On a `disconnect` frame with `link_disabled`, `run` stops.
4. When the connection closes without a `disconnect` frame, the client waits, then opens a new one.
5. When an open fails with a network or TLS error, a transport error, or `Slack::Api::RateLimited`, the client waits and tries again. Other Slack errors, such as `invalid_auth` or `not_allowed_token_type`, stop `run` and raise `Slack::Api::Error`. See [When Slack rejects the app token](#when-slack-rejects-the-app-token).

Failed opens and unexpected closes count as failures until a connection receives `hello`. The wait after failure *n* is 1, 2, 4, … seconds, at most 30, or the `Retry-After` time. The client limits DNS, TCP connect, TLS, and the WebSocket handshake to 10 seconds each.

`close` asks `run` to stop. It ends a wait or a handshake in progress. Before `run` returns, it waits for the running blocks and sends their acknowledgments. A block that never returns keeps `run` from returning.

### When Slack rejects the app token

When `apps.connections.open` fails with an error that the client does not retry, `run` raises `Slack::Api::Error`. `error.code` is the Slack error name. The client does not retry this error, and it does not exit the process. Rescue the error around `run`:

```crystal
begin
  receiver.run
rescue error : Slack::Api::Error
  STDERR.puts "Slack did not open a Socket Mode connection: #{error.code}"
  exit 1
end
```

Before `run` raises, the client stops its fibers and closes its channels. If connections were open before, it first waits for the running blocks, sends their acknowledgments, and closes the connection.

The client calls `apps.connections.open` again for each reconnect. If Slack rejects the token on a reconnect, `run` raises the same error in the same way. Thus one rescue covers a start that fails and a token that stops working later.

The [`apps.connections.open` reference](https://docs.slack.dev/reference/methods/apps.connections.open) lists the error codes. These codes are about the token:

- `invalid_auth`: the app-level token is not valid.
- `not_allowed_token_type`: the token is not an app-level (`xapp-`) token, for example a bot token.
- `not_authed`: the request has no token.
- `token_expired` and `token_revoked`: the token no longer works.
- `account_inactive`: the token is for a deleted user or workspace.

Other codes on that page also stop `run`, for example `internal_error`, `fatal_error`, and `service_unavailable`. The library codes `invalid_response` and `http_error` stop `run` too.

These errors do not get to the rescue. The client waits and tries again until `close`:

- network and TLS errors (`IO::Error`, `OpenSSL::Error`),
- transport failures, and
- rate limits (HTTP 429, `Slack::Api::RateLimited`).

A second call to `run` on the same client raises `ArgumentError`. This is a program error, so do not rescue it.

The client keeps one connection. Slack allows up to 10 for an app and can send each envelope to any of them. `HTTP::WebSocket` answers Slack's ping frames. The client sends all acknowledgments on the current connection, from one writer fiber.

The offline specs use a local WebSocket server. They do not prove live Slack delivery, reconnect timing, or acceptance of acknowledgments.

## App receiver

To route envelopes to `Slack::App` listeners, give the client to `Slack::App::SocketModeReceiver`. The receiver acknowledges each envelope with the listener's `ack` body. See [App listeners](app.md#socket-mode-receiver).

```crystal
Slack::App::SocketModeReceiver.new(app, Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])).run
```

Socket Mode needs no request signature verification. Slack authenticates the WebSocket connection with the app-level token.

## Frames

`Slack::SocketMode::Frame.parse` decodes one text frame into one of four types:

| Type | Frame | Fields |
| --- | --- | --- |
| `Hello` | `hello` | `num_connections` (Slack allows up to 10), `app_id`, `approximate_connection_time` (seconds, from `debug_info`; can be nil) |
| `Disconnect` | `disconnect` | `reason` (`Warning`, `RefreshRequested`, `LinkDisabled`, `Unknown`), `reason_name`, raw `debug_info` |
| `Envelope` | any frame with an `envelope_id` | `envelope_id`, `kind` (`EventsApi`, `Interactive`, `SlashCommands`, `Unknown`), `type`, `payload_json`, `accepts_response_payload?`, `retry_attempt`, `retry_reason` |
| `UnknownFrame` | other frames | `type`, `raw` |

A malformed field raises `Slack::TypeMismatch` with the field path.

`retry_attempt` and `retry_reason` are SDK-sourced (Bolt JS socket-mode client); they are not on the Slack reference page. They are nil when absent.

## Payloads

The envelope keeps the payload as JSON text in `payload_json` and does not decode it. Decode it with a `Slack::Decoder`. Interaction and command payloads are JSON objects, so give the `:json` format. The decoder applies the same rules as it does for HTTP payloads.

```crystal
decoder = Slack::Decoder.default
envelope = Slack::SocketMode::Frame.parse(text)
if envelope.is_a?(Slack::SocketMode::Envelope)
  case envelope.kind
  in .events_api?     then decoder.event(envelope.payload_json)              # Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
  in .interactive?    then decoder.interaction(envelope.payload_json, :json) # Slack::Interaction
  in .slash_commands? then decoder.command(envelope.payload_json, :json)     # Slack::Command
  in .unknown?        then nil
  end
end
```

When your code expects one kind, give the kind to `payload_json`. For another kind, it raises `Slack::TypeMismatch`:

```crystal
command = decoder.command(envelope.payload_json(:slash_commands), :json)
```

`payload_json` is the exact bytes of the `payload` value in the frame, with its whitespace and string escapes. `Frame.parse` reads the frame with the FusedJSON pull parser and cuts the payload out of the frame text.

For a command payload, the default decoder uses `Slack::Commands::Parser.from_json_object`. It applies the form parser rules: a repeated routing field raises `Slack::Auth::RequestAuthorizationError`, and `is_enterprise_install` must be `"true"` or `"false"` (a JSON boolean is also accepted).

## Acknowledgments

Acknowledge every envelope within three seconds. Send the JSON of `Slack::SocketMode::Acknowledgment` as a text frame:

```crystal
Slack::SocketMode::Acknowledgment.new(envelope.envelope_id).to_json
# => {"envelope_id":"..."}

errors = Slack::Interactions::ModalErrors.new({"request.reason" => "Enter a reason."})
Slack::SocketMode::Acknowledgment.new(envelope.envelope_id, errors).to_json
# => {"envelope_id":"...","payload":{"response_action":"errors","errors":{...}}}
```

The payload can be any type that includes `Slack::SocketMode::ResponsePayload`: `ModalErrors`, `ModalPush`, `ModalUpdate`, `ModalClear`, `BlockSuggestionResponse`, or `Slack::Commands::Response`. Send a payload only when `accepts_response_payload?` is true.

The specs use synthetic frames. They do not prove live frame shapes, delivery, or timing.

## Examples

| Example | Shows |
| --- | --- |
| [`socket_mode_protocol.cr`](../examples/socket_mode_protocol.cr) | Synthetic frames and their acknowledgments, without a connection |
| [`socket_mode_client.cr`](../examples/socket_mode_client.cr) | A client connected to a local WebSocket server |
| [`socket_mode_app.cr`](../examples/socket_mode_app.cr) | App listeners that answer a slash command and a view submission |
