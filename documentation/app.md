# App listeners

`Slack::App` routes verified Slack requests to listeners. `Slack::App::HttpReceiver` serves the requests over HTTP, and `Slack::App::SocketModeReceiver` receives them over Socket Mode. This is the layer that Bolt calls `App`. To handle requests without this layer, see [Events and interactions](events-and-interactions.md).

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

The offline example `examples/app.cr` sends a signed `app_mention` and a button click through the receiver. It also sends a slash command whose listener uses `say` and `respond`.

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
| `assistant(assistant)` | App thread events and user messages in the app's direct messages | `AssistantContext(E)`: `envelope`, `event`, `say`, `set_status`, `stream` | Automatic, before the handler runs |

Matching rules:

- A string ID matches the complete value. A `Regex` matches when it finds a match in the value.
- A string `message` pattern matches text that contains it, as in Bolt. A `Regex` matches the text. Nil matches every message.
- `action` uses the first action of the payload. Slack sends one action for each click.
- For each request, only the first matching listener runs, in registration order.
- `assistant` adds the handlers of a `Slack::App::Assistant`. See [Answer app threads with the assistant helper](ai-apps.md#answer-app-threads-with-the-assistant-helper).
- `ActionContext` and `ViewContext` give `function_execution` for blocks and views that a custom step created. See [Handle a step](workflows.md#handle-a-step).

Every context also gives:

- `client`: the `Slack::Api::Client` from the authorizer. In `FunctionContext`, `client` has the event's workflow token (`bot_access_token`).
- `say` and `respond`, on the contexts that support them. See [Reply with say and respond](#reply-with-say-and-respond).
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

If a listener raises before the request has a response, the receiver answers 500. If it raises after, the response stays as sent. In both cases the app gives the exception to the [error handler](#error-handler). For events, the app acknowledges before the listener runs, so an exception in the listener does not cause a retry.

## Reply with say and respond

`say` posts a message with `chat.postMessage` to the channel of the payload. It uses `ctx.client`, so an installation's credential check applies before the send. It returns the `Slack::Models::Chat::PostMessage` result. Give plain text or a `Slack::UI::Message`, and optionally `thread_ts`, `attachments`, and `metadata`.

`respond` posts a `Slack::Interactions::ResponseUrlMessage` to the `response_url` of the payload. The post has no token. Slack accepts up to five posts to one `response_url` within 30 minutes.

```crystal
app.command("/deploy") do |ctx|
  ctx.ack
  ctx.say("Deploying #{ctx.command.text}.")
  ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Only you can see this."))
end

app.message("status") do |ctx|
  # A reply goes into a thread only when you give thread_ts.
  ctx.say("All green.", thread_ts: ctx.message.thread_ts || ctx.message.ts)
end

app.action("deploy.approve") do |ctx|
  ctx.ack
  ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Approved.", replace_original: true))
end
```

| Context | `say` channel | `respond` URL |
| --- | --- | --- |
| `EventContext` | The event's channel: messages, `app_mention`, `app_home_opened`, `member_joined_channel`, `member_left_channel`, reactions on messages, pins, `link_shared` | — |
| `MessageContext` | `message.channel` | — |
| `CommandContext` | `command.channel_id` | `command.response_url` |
| `ActionContext` | `payload.channel` (messages only) | `payload.response_url` (messages only) |
| `ShortcutContext` | The channel of a message shortcut | The `response_url` of a message shortcut |

If the payload has no channel or `response_url`, for example for a click in a modal, the call raises `Slack::App::NoReplyTarget`. `say` raises the errors of `Api::Client#call`. `respond` raises `Slack::Interactions::ResponseUrlError` for a non-2xx status.

The app sends `respond` posts through its `response_url_transport`, not through the client, because the URL is not a Web API URL. The default is an HTTP transport. Give a different one with `Slack::App.new(authorizer: ..., response_url_transport: transport)`, for example `Slack::Testing::RecordingTransport` in specs.

## Error handler

`app.error` sets one handler for the exceptions that listeners and their middleware raise. Without a handler, the app logs `error.message`.

```crystal
app.error do |error, ctx|
  ctx.log.error { "#{error.payload_kind} failed: #{error.cause.class}" }
  notify_on_call(error.route) unless error.acknowledged?
end
```

The handler gets a `Slack::App::ListenerError` and the listener's context:

- `payload_kind`: for example `event app_mention`, `command /deploy`, or `block_actions`.
- `route`: the context type, for example `Slack::App::CommandContext`.
- `acknowledged?`: true when the request had its response before the exception. When false, the receiver answered 500.
- `cause`: the original exception.

The error message never contains the payload or the message of the original exception, because they can hold user data. The handler runs in the listener fiber after the response. If the handler raises, the app logs the exception class.

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
- `InstallationAuthorizer.new(request_authorizer, grant)`: finds the installation that owns the request through `Slack::Auth::RequestAuthorizer#authorize_trusted`. The client holds no token; the scoped transport reads the stored credential immediately before each send. If a grant is revoked after authorization, the next send raises `Slack::Auth::ContractError`, and the error handler receives it. See [authentication](authentication.md).

If the authorizer raises, no listener runs and the receiver answers 401.

### Act as the user

`ctx.client` sends the app-wide token, usually the bot token. To act as a user for one call, give `ctx.client` a grant. Slack does write actions with a user token as if the user did them:

```crystal
app.command("/standup") do |ctx|
  ctx.ack
  as_user = ctx.client(Slack::Auth::GrantKey.new(:user, ctx.command.user_id))
  as_user.call(Slack::Api::ChatPostMessage.new(channel: ctx.command.channel_id, text: "Yesterday: shipped the deploy fix."))
end
```

The user must install or authorize the app with the user scopes that the call needs. Request them in the OAuth flow:

```crystal
handler = Slack::AuthHandler.new(oauth, state_store, transport,
  bot_scopes: ["commands", "chat:write"], user_scopes: ["chat:write"])
```

`AuthHandler#authenticate_user` returns the `AuthResponse`; it does not store it. Your code must store `response.installation_patch(clock)` in the store that the `RequestAuthorizer` uses. The patch holds the user grant beside the bot grant. See [Persist the installation](authentication.md#persist-the-installation).

- With `InstallationAuthorizer`, each `ctx.client(grant)` call finds the grant in the installation that sent the request. The client does not keep a token: the store checks the grant immediately before each send. A user without a stored grant, or a grant that is revoked, raises `Slack::Auth::ContractError`, and the error handler receives it. The app does not select a grant by scope.
- `SingleTokenAuthorizer.new(client, grant)` has one token. `ctx.client(grant)` returns that client only for the grant it was built for (the bot by default). Other grants raise `Slack::App::GrantUnavailable`. The error names the payload kind and the grant; it holds no token.

### Token rotation

Give the `RequestAuthorizer` a `Slack::Auth::RotationService`. Then the authorizer refreshes an access token that expires soon before the listener runs, and the listener's `client`, `say`, and `respond` do not change:

```crystal
rotation = Slack::Auth::RotationService.new(store, Slack::Auth::RefreshClient.new(oauth_configuration, transport))
request_authorizer = Slack::Auth::RequestAuthorizer.new(app_id, store, transport, api_configuration, verifier, rotation: rotation)
app = Slack::App.new(authorizer: Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot)))
```

### Revoked tokens and uninstalls

`tokens_revoked` and `app_uninstalled` events can arrive after the installation is gone. Give the app a `Slack::Auth::CredentialLifecycle` for the same store:

```crystal
app.lifecycle(Slack::Auth::CredentialLifecycle.new(app_id, store, verifier))
```

The app then applies these events before authorization: it removes the revoked grants or the installation, and answers with an empty 200. These events do not go to listeners. If the cleanup raises, the receiver answers 500 and Slack sends the event again.

Slack's `tokens_revoked` example has no `authorizations`. For such events, give a block that selects the exact installation from your own routing. The lifecycle still checks the key against the event's app and workspace:

```crystal
app.lifecycle(lifecycle) do |envelope|
  Slack::Auth::InstallationKey.new(app_id, :workspace, team_id: envelope.team_id)
end
```

The app keeps the preparation of each lifecycle event in memory, by event ID, and applies the same preparation to a repeated delivery. Thus a retry after a reinstall does not remove the new installation. A retry that the process has no preparation for, for example after a restart or on a different process, gets an empty 200 without cleanup and a warning in the log. If you run more than one process, or you must survive restarts, keep your own delivery history and use `Slack::Auth::CredentialLifecycle` before the receiver. See [authentication](authentication.md).

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

## Decoders

The receivers decode payloads with a `Slack::Decoder`. The default is `Slack::Decoders::Stdlib`, which uses the standard library `JSON` parser. `HttpReceiver`, `SocketModeReceiver`, `Slack::Auth::RequestAuthorizer`, and `Slack::Auth::CredentialLifecycle` accept another decoder through `decoder:`.

To capture the payloads that Slack sends, for example for a bug report or a test fixture, give the decoder an observer. The decoder calls the observer with the payload kind and body before it decodes the payload. The observer is off by default.

```crystal
decoder = Slack::Decoders::Stdlib.new(->(kind : Slack::Decoder::Kind, body : String) {
  Log.debug { "#{kind} payload: #{body}" }
  nil
})
Slack::App::HttpReceiver.new(app, verifier, decoder: decoder)
Slack::App::SocketModeReceiver.new(app, socket, decoder: decoder)
```

- Over HTTP, the observer gets the body only after the signature check. The body is the exact request bytes: JSON for an event, and the form for an interaction or a slash command.
- Over Socket Mode, the observer gets the envelope `payload` as JSON. The frame parser copies it, so whitespace and string escapes can differ from the frame.
- If the observer raises, the payload is not decoded, and the receiver answers as it does when a listener raises.

Payloads can contain user messages and other private data. Keep captured payloads as you keep other user data.

## Logging

The app logs with the standard `Log` module: source `slack.app` for routing, authorization, credential cleanup, and listeners, and `slack.app.receiver` for rejected requests. Logs contain payload kinds, IDs such as the command name, and exception classes. They never contain bodies, headers, or tokens.

## Limits of the offline tests

The specs and the example run requests in memory with synthetic credentials. They do not prove that Slack accepts the responses or the `say` and `respond` posts, the three-second timing on a live network, or retry behavior.

## Examples

| Example | Shows |
| --- | --- |
| [`app.cr`](../examples/app.cr) | A signed mention, a button click, and a slash command with `say` and `respond`, through the HTTP receiver; a click that reacts with the user's token |
| [`socket_mode_app.cr`](../examples/socket_mode_app.cr) | Listeners that answer a slash command and a view submission over Socket Mode |
| [`custom_step.cr`](../examples/custom_step.cr) | A custom step that waits for a button click, then completes |
| [`assistant.cr`](../examples/assistant.cr) | An assistant that greets an app thread and streams an answer |
| [`testing.cr`](../examples/testing.cr) | An offline test of a slash command handler |
