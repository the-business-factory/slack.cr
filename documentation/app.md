# App listeners

`Slack::App` routes verified Slack requests to listeners. `Slack::App::HttpReceiver` serves the requests over HTTP. This is the layer that Bolt calls `App`. Socket Mode, `say`, `respond`, and an error handler are not part of this layer yet.

## Minimal app

```crystal
require "slack"

client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))

app.event("app_mention") do |ctx|
  mention = ctx.event
  next unless mention.is_a?(Slack::Events::AppMentioned)
  ctx.client.call(Slack::Api::ChatPostMessage.new(channel: mention.channel, text: "Hello <@#{mention.user}>."))
end

app.command("/deploy") do |ctx|
  ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}."))
end

verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(ENV["SLACK_SIGNING_SECRET"]))
server = HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier)])
server.bind_tcp("0.0.0.0", 3000)
server.listen
```

Set the Events API Request URL, the Interactivity Request URL, the Options Load URL, and each slash command URL to `https://<your host>/slack/events`. To use a different path, give it as the third argument: `HttpReceiver.new(app, verifier, "/slack/requests")`.

The offline example `examples/app.cr` sends a signed `app_mention` and a button click through the receiver.

## Listeners

Register listeners before the app receives requests. Each registration method gives the block a typed context.

| Method | Payload | Context | Acknowledgment |
| --- | --- | --- | --- |
| `event(type)` | Events API event of `type` | `EventContext`: `envelope`, `event` | Automatic, before the listener runs |
| `message(pattern = nil)` | `message` event without a subtype | `MessageContext`: `envelope`, `message` | Automatic, before the listener runs |
| `function(callback_id)` | `function_executed` | `FunctionContext`: `envelope`, `event`, `inputs`, `complete`, `fail` | Automatic, before the listener runs |
| `action(action_id, block_id = nil)` | `block_actions` | `ActionContext`: `payload`, `action` | `ack` |
| `command(name)` | Slash command | `CommandContext`: `command` | `ack`, `ack(Commands::Response)` |
| `shortcut(callback_id)` | Global or message shortcut | `ShortcutContext`: `shortcut` | `ack` |
| `options(action_id)` | `block_suggestion` | `OptionsContext`: `payload` | `ack(BlockSuggestionResponse)` |
| `view(callback_id)` | `view_submission` | `ViewContext`: `payload` | `ack`, `ack(ModalErrors \| ModalPush \| ModalUpdate \| ModalClear)` |
| `view_closed(callback_id)` | `view_closed` | `ViewClosedContext`: `payload` | `ack` |

Matching rules:

- A string ID matches the complete value. A `Regex` matches when it finds a match in the value.
- A string `message` pattern matches text that contains it, as in Bolt. A `Regex` matches the text. Nil matches every message.
- `action` uses the first action of the payload. Slack sends one action for each click.
- For each request, only the first matching listener runs, in registration order.
- `ActionContext` and `ViewContext` give `function_execution` for blocks and views that a custom step created. See [Handle a step](workflows.md#handle-a-step).

Every context also gives:

- `client`: the `Slack::Api::Client` from the authorizer. In `FunctionContext`, `client` has the event's workflow token (`bot_access_token`).
- `log`: the app `Log` (source `slack.app`).
- `delivery`: the Events API retry headers (`Slack::Events::Delivery`), or nil for other requests.
- `store`: a `Hash(String, String)` that middleware uses to give values to later steps of the same request.

## Acknowledge within three seconds

Slack expects an HTTP 200 within three seconds. Otherwise it shows an error to the user or retries the event. The receiver sends the response when one of these occurs first:

1. The listener calls `ack`. The response contains the body that you give.
2. The listener returns without `ack`. The response is an empty 200.
3. The `ack_timeout` passes (default 2.5 seconds). The response is an empty 200, and the app logs a warning.

The listener runs in its own fiber. After the response, the listener continues until it returns. Thus, call `ack` first and do slow work after it:

```crystal
app.view("deploy.form") do |ctx|
  reason = ctx.payload.plain_text?("reason", "reason.text")
  if reason.nil? || reason.size < 10
    ctx.ack(Slack::Interactions::ModalErrors.new({"reason" => "Enter at least 10 characters."}))
    next
  end
  ctx.ack
  start_deploy(reason) # runs after Slack has the response
end
```

`ack` is single-use. A second `ack`, or an `ack` after the timeout, raises `Slack::App::AlreadyAcknowledged`. `ack` with an invalid body raises `Slack::UI::ValidationError`. Change the timeout with `Slack::App.new(authorizer: ..., ack_timeout: 2.seconds)`.

If a listener raises before the request has a response, the receiver answers 500. If it raises after, the response stays as sent. In both cases the app logs the exception class. For events, the app acknowledges before the listener runs, so an exception in the listener does not cause a retry.

## Middleware

Global middleware runs for each request that matches a listener, before the listener. Listener middleware runs after global middleware, for one listener only. A step that does not call `call_next` stops the chain, and the request gets an empty 200.

```crystal
app.use do |ctx, call_next|
  ctx.store["started_at"] = Time.utc.to_rfc3339
  call_next.call
end

only_admins = Slack::App::Middleware.new do |ctx, call_next|
  call_next.call if ctx.is_a?(Slack::App::CommandContext) && ADMINS.includes?(ctx.command.user_id)
end
app.command("/purge", middleware: [only_admins]) { |ctx| ctx.ack }
```

## Authorization

The app calls its authorizer after it decodes a request and before it routes it. The authorizer gives the `client` for that request.

- `SingleTokenAuthorizer.new(client)`: one client for all requests. Use it for an app in one workspace.
- `InstallationAuthorizer.new(request_authorizer, grant)`: finds the installation that owns the request through `Slack::Auth::RequestAuthorizer#authorize_trusted`. The client holds no token; the scoped transport reads the stored credential immediately before each send. See [authentication](authentication.md).

If the authorizer raises, no listener runs and the receiver answers 401. `tokens_revoked` and `app_uninstalled` events can arrive after the installation is gone. Handle them with `Slack::Auth::CredentialLifecycle` before the receiver.

## HTTP receiver

`HttpReceiver` is an `HTTP::Handler`. For each POST to its path, it:

1. Reads the body once and verifies the signature and timestamp. A failure gives 401.
2. Decodes the body. `application/json` is an Events API request. A form with a `payload` field is an interaction. Another form is a slash command. A body that does not decode gives 400; another content type gives 415.
3. Answers a `url_verification` challenge with `{"challenge": "..."}`, and an `ssl_check` form with an empty 200. Other envelopes without an event also get an empty 200.
4. Calls `App#dispatch` and writes the result: 200 with an empty or JSON body, 401, or 500.

Requests for other paths go to the next handler. Bolt's custom routes are ordinary Crystal handlers in the same server:

```crystal
HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier), HealthCheckHandler.new])
```

The receiver does not remove duplicate event deliveries. Use `ctx.envelope.event_id` and `ctx.delivery` for that.

## Socket Mode receiver

`SocketModeReceiver` gives the same app its payloads over Socket Mode. The `Slack::SocketMode::Client` owns the connection; see [Socket Mode](socket-mode.md).

```crystal
socket = Slack::SocketMode::Client.new(Slack::Auth::Secret.new(ENV["SLACK_APP_TOKEN"]))
receiver = Slack::App::SocketModeReceiver.new(app, socket)
receiver.run # Returns after receiver.close or when Slack turns Socket Mode off.
```

Slack authenticates the WebSocket with the app-level token. The receiver does not verify signatures, and it needs no signing secret.

For each envelope, the receiver:

1. Decodes the payload: `events_api` as an Events API request, `interactive` as an interaction, `slash_commands` as a slash command.
2. Calls `App#dispatch`. An event listener gets `ctx.delivery` from the envelope `retry_attempt` and `retry_reason`. A first delivery has neither.
3. Acknowledges with the listener's `ack` body, for example `{"envelope_id":"...","payload":{"response_action":"errors",...}}`. An envelope that does not accept a response payload gets a plain acknowledgment, and the receiver logs a warning.

Envelopes of an unknown type and envelopes without an event get a plain acknowledgment. The receiver does not acknowledge an envelope when its payload does not decode, the authorizer raises, or a listener raises before `ack`. Slack can then send it again. The HTTP receiver answers these cases with 400, 401, or 500.

The receiver logs with source `slack.app.socket_mode_receiver`. The logs contain envelope IDs, types, and exception classes, but no payloads or tokens.

## Logging

The app logs with the standard `Log` module: source `slack.app` for routing, authorization, and listeners, and `slack.app.receiver` for rejected requests. Logs contain payload kinds, IDs such as the command name, and exception classes. They never contain bodies, headers, or tokens.

## Limits of the offline tests

The specs and the example run requests in memory with synthetic credentials. They do not prove that Slack accepts the responses, the three-second timing on a live network, or retry behavior.
