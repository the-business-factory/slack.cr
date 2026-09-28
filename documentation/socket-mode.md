# Socket Mode

Socket Mode sends events, interactions, and slash commands over a WebSocket instead of to a public HTTP endpoint. `Slack::SocketMode::Client` keeps the connection open. The frame and acknowledgment types below also work without the client. See the [Slack guide](https://docs.slack.dev/apis/events-api/using-socket-mode).

## Client

Give the client an app-level token (`xapp-`). `run` calls the block on a new fiber for each envelope. Call `ack.ack` once for each envelope, within three seconds.

```crystal
client = Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])
client.run do |envelope, ack|
  case envelope.kind
  in .slash_commands?
    command = envelope.command
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
5. When an open fails with a network or TLS error, a transport error, or `Slack::Api::RateLimited`, the client waits and tries again. Other Slack errors, such as `invalid_auth`, stop `run` and raise.

Failed opens and unexpected closes count as failures until a connection receives `hello`. The wait after failure *n* is 1, 2, 4, … seconds, at most 30, or the `Retry-After` time. The client limits DNS, TCP connect, TLS, and the WebSocket handshake to 10 seconds each.

`close` asks `run` to stop. It ends a wait or a handshake in progress. Before `run` returns, it waits for the running blocks and sends their acknowledgments. A block that never returns keeps `run` from returning.

The client keeps one connection. Slack allows up to 10 for an app and can send each envelope to any of them. `HTTP::WebSocket` answers Slack's ping frames. The client sends all acknowledgments on the current connection, from one writer fiber.

The offline specs use a local WebSocket server. They do not prove live Slack delivery, reconnect timing, or acceptance of acknowledgments.

## Frames

`Slack::SocketMode::Frame.parse` decodes one text frame into one of four types:

| Type | Frame | Fields |
| --- | --- | --- |
| `Hello` | `hello` | `num_connections` (Slack allows up to 10), `app_id`, `approximate_connection_time` (seconds, from `debug_info`; can be nil) |
| `Disconnect` | `disconnect` | `reason` (`Warning`, `RefreshRequested`, `LinkDisabled`, `Unknown`), `reason_name`, raw `debug_info` |
| `Envelope` | any frame with an `envelope_id` | `envelope_id`, `kind` (`EventsApi`, `Interactive`, `SlashCommands`, `Unknown`), `type`, `payload`, `accepts_response_payload?`, `retry_attempt`, `retry_reason` |
| `UnknownFrame` | other frames | `type`, `raw` |

A malformed field raises `Slack::Interactions::TypeMismatch` with the field path.

`retry_attempt` and `retry_reason` are SDK-sourced (Bolt JS socket-mode client); they are not on the Slack reference page. They are nil when absent.

## Payloads

Decode the payload with the method for the envelope kind. The wrong method raises `Slack::Interactions::TypeMismatch`.

```crystal
envelope = Slack::SocketMode::Frame.parse(text)
if envelope.is_a?(Slack::SocketMode::Envelope)
  case envelope.kind
  in .events_api?     then envelope.event       # Slack::VerifiedEvent | Slack::UrlVerification | Slack::AppRateLimited
  in .interactive?    then envelope.interaction # Slack::Interaction
  in .slash_commands? then envelope.command     # Slack::Command
  in .unknown?        then nil
  end
end
```

The command payload is a JSON object. `Slack::Commands::Parser.from_json_object` applies the form parser rules: a repeated routing field raises `Slack::Auth::RequestAuthorizationError`, and `is_enterprise_install` must be `"true"` or `"false"` (a JSON boolean is also accepted).

## Acknowledgments

Acknowledge every envelope within three seconds. Send the JSON of `Slack::SocketMode::Acknowledgment` as a text frame:

```crystal
Slack::SocketMode::Acknowledgment.new(envelope.envelope_id).to_json
# => {"envelope_id":"..."}

errors = Slack::Interactions::ModalErrors.new({"request.reason" => "Enter a reason."})
Slack::SocketMode::Acknowledgment.new(envelope.envelope_id, errors).to_json
# => {"envelope_id":"...","payload":{"response_action":"errors","errors":{...}}}
```

The payload can be `ModalErrors`, `ModalPush`, `ModalUpdate`, `ModalClear`, `BlockSuggestionResponse`, or `Slack::Commands::Response`. Send a payload only when `accepts_response_payload?` is true.

The specs use synthetic frames. They do not prove live frame shapes, delivery, or timing.
