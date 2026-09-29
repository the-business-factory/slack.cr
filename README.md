# slack.cr

A Crystal library for Slack apps: Web API calls, Block Kit, signed events, interactions, and slash commands, Socket Mode, an app framework with listeners, OAuth installation and token rotation, AI app threads, workflow steps, and files. Requires Crystal 1.21.0 or later.

## Installation

Add the shard to `shard.yml`:

```yaml
dependencies:
  slack:
    github: the-business-factory/slack.cr
```

Run `shards install` and use the full library with `require "slack"`.

## App quickstart

`Slack::App` routes verified requests to typed listeners, as Bolt's `App` does. `Slack::App::HttpReceiver` is an `HTTP::Handler` that verifies the signature, decodes the request, calls the listener, and writes the acknowledgment.

```crystal
require "slack"

client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))

app.event("app_mention") do |ctx|
  mention = ctx.event
  next unless mention.is_a?(Slack::Events::AppMentioned)
  ctx.say("Hello <@#{mention.user}>.")
end

app.command("/deploy") do |ctx|
  ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}."))
end

app.action("deploy.approve") do |ctx|
  ctx.ack
  ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Approved.", replace_original: true))
end

verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(ENV["SLACK_SIGNING_SECRET"]))
server = HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier)])
server.bind_tcp("0.0.0.0", 3000)
server.listen
```

Set the Events API, Interactivity, and slash command Request URLs to `https://<your host>/slack/events`. The bot token needs `app_mentions:read`, `chat:write`, and `commands`. The receiver answers when the listener calls `ack` or returns, or after 2.5 seconds. See [App listeners](documentation/app.md).

## Web API quickstart

Create one `Slack::Api::Client` with a token. Send typed requests with `call`:

```crystal
require "slack"

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
team = client.call(Slack::Api::TeamInfo.new)
puts team.name

client.call(Slack::Api::ChatPostMessage.new(channel: "C123", text: "Deploy finished."))

# A method without a typed request: form fields in, raw JSON out.
dnd = client.call("dnd.info", {user: "U123"})
dnd["snooze_enabled"].as_bool
```

The token must have the scope that each Slack method requires. A Slack error raises `Slack::Api::Error` with Slack's error name in `code`. The client paces each method locally at its rate limit tier. See [Web API](documentation/web-api.md) for requests, errors, rate limits, retries, pagination, and files.

## Block Kit

`Slack::UI` builds validated, immutable Block Kit values. Construction needs no credentials, and the surface type rejects a block that Slack does not allow there:

```crystal
APPROVE = Slack::UI::ActionId.new("request.approve")

message = Slack::UI.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(Slack::UI.mrkdwn("*Request 42* needs approval"))
  builder.actions(elements: [
    Slack::UI::BlockElements::Button.new(
      text: Slack::UI.plain("Approve"), action_id: APPROVE, value: "42"),
  ])
end
client.call(Slack::Api::ChatPostMessage.new(channel: "C123", message: message))

app.action(APPROVE) { |ctx| ctx.ack }
```

An `action_id:` argument takes a `String` or a `Slack::UI::ActionId`. `app.action` and `app.options` also take an `ActionId`. Use one `ActionId` constant for an element and its listener. Then the two cannot use different IDs.

Use `message.to_pretty_json` to inspect the payload locally. See [Block Kit](documentation/block-kit.md) for surfaces, blocks, elements, modals, Home, and received blocks.

## Features

| Feature | Main types | Guide |
| --- | --- | --- |
| Web API | `Slack::Api::Client`, typed requests, `RetryPolicy`, `each_page`, the generic call | [Web API](documentation/web-api.md) |
| Files | `Slack::Api::FileUpload`, `FilesRemoteAdd`, `FilesRemoteShare` | [Files](documentation/web-api.md#files) |
| Block Kit | `Slack::UI` surfaces, blocks, elements, attachments, plan and task cards; `Slack::Interactions::ReceivedBlock` | [Block Kit](documentation/block-kit.md) |
| Events, interactions, and commands | `Slack::Webhooks::Verifier`, `Slack::Events.parse`, `Slack::Interactions.parse`, `Slack::Commands.parse`, acknowledgments, `ResponseUrlResponder` | [Events and interactions](documentation/events-and-interactions.md) |
| Socket Mode | `Slack::SocketMode::Client`, `Frame`, `Acknowledgment` | [Socket Mode](documentation/socket-mode.md) |
| App framework | `Slack::App`, listeners, middleware, `say` and `respond`, HTTP and Socket Mode receivers | [App listeners](documentation/app.md) |
| OAuth and token rotation | `Slack::AuthHandler`, `Slack::Auth::RequestAuthorizer`, `RotationService`, `CredentialLifecycle`, installation stores | [Authentication](documentation/authentication.md) |
| AI apps | `Client#start_stream`, `MessageStream`, app thread and agent session requests, `Slack::App::Assistant` | [AI apps](documentation/ai-apps.md) |
| Workflow steps | `Slack::Events::FunctionExecuted`, `FunctionsCompleteSuccess`, `App#function` | [Workflow steps](documentation/workflows.md) |
| Testing | `Slack::Testing::SignedRequest`, `Slack::Testing::RecordingTransport` | [Testing your app](#testing-your-app) |

The library has no global settings and reads no environment variables. Give each credential to the object that uses it: a token to `Slack::Api::Client`, the signing secret to `Slack::Webhooks::Verifier`, an app-level token to `Slack::SocketMode::Client`, and a `Slack::Auth::OAuthConfiguration` to `Slack::AuthHandler`. Tokens and secrets are `Slack::Auth::Secret` values; `inspect` and `to_s` show `[REDACTED]`.

## Testing your app

Test handlers offline with `require "slack/testing"`. `require "slack"` does not load it.

- `Slack::Testing::SignedRequest.build` makes a POST request with a valid `X-Slack-Signature` and `X-Slack-Request-Timestamp`. `Webhooks::Verifier` accepts it with the same signing secret.
- `Slack::Testing::RecordingTransport` is a transport for `Slack::Api::Client`. It records each request and answers with the responses that you queue. A request without a response raises `Slack::Testing::UnstubbedRequest`.

```crystal
require "slack"
require "slack/testing"

secret = Slack::Auth::Secret.new("synthetic-signing-secret")
request = Slack::Testing::SignedRequest.build(form_body, signing_secret: secret,
  path: "/slack/commands", content_type: "application/x-www-form-urlencoded")

transport = Slack::Testing::RecordingTransport.new
transport.respond(%({"ok":true,"channel":"C123","ts":"1710000000.000100","message":{"type":"message","ts":"1710000000.000100"}}))
client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport)

handler.handle(request) # your code verifies the request and calls client
transport.requests.first.uri.path # => "/api/chat.postMessage"
transport.requests.first.body     # => %({"channel":"C123","text":"..."})
```

Queued responses are used in order. To compute answers, give a block to `RecordingTransport.new`; the block answers when the queue is empty. Recorded requests contain the token, so use synthetic credentials. These tools do not prove that Slack accepts a request.

## Runnable examples

From a repository checkout, run `shards install` first. The examples use synthetic credentials and stubbed HTTP or local servers; they do not contact Slack. Each guide describes its examples.

Web API ([guide](documentation/web-api.md#examples)):

```sh
crystal run examples/web_api.cr
crystal run examples/retry_policy.cr
crystal run examples/thread_history.cr
crystal run examples/user_group.cr
crystal run examples/incident_channel.cr
crystal run examples/incident_triage.cr
crystal run examples/file_upload.cr
crystal run examples/app_manifest.cr
```

Block Kit ([guide](documentation/block-kit.md#offline-examples)):

```sh
crystal run examples/block_kit_message.cr
crystal run examples/block_kit_message_update.cr
crystal run examples/attachments.cr
crystal run examples/ephemeral_reply.cr
crystal run examples/block_kit_remote_file.cr
crystal run examples/block_kit_overflow.cr
crystal run examples/block_kit_checkboxes.cr
crystal run examples/block_kit_radio_buttons.cr
crystal run examples/block_kit_static_select.cr
crystal run examples/block_kit_users_select.cr
crystal run examples/block_kit_channels_select.cr
crystal run examples/block_kit_conversations_select.cr
crystal run examples/block_kit_date_time_pickers.cr
crystal run examples/block_kit_datetime_picker.cr
crystal run examples/block_kit_external_select.cr
crystal run examples/block_kit_context_actions.cr
crystal run examples/block_kit_workflow_button.cr
crystal run examples/block_kit_video.cr
crystal run examples/block_kit_rich_text.cr
crystal run examples/block_kit_table.cr
crystal run examples/block_kit_markdown.cr
crystal run examples/block_kit_alert.cr
crystal run examples/block_kit_data_table.cr
crystal run examples/block_kit_data_visualization.cr
crystal run examples/block_kit_card_carousel.cr
crystal run examples/block_kit_container.cr
crystal run examples/block_kit_number_input.cr
crystal run examples/block_kit_file_input.cr
crystal run examples/block_kit_url_input.cr
crystal run examples/block_kit_email_input.cr
crystal run examples/block_kit_rich_text_input.cr
crystal run examples/block_kit_modal.cr
crystal run examples/block_kit_modal_update.cr
crystal run examples/block_kit_modal_push.cr
crystal run examples/block_kit_modal_errors.cr
crystal run examples/block_kit_modal_clear.cr
crystal run examples/block_kit_view_update.cr
crystal run examples/block_kit_view_push.cr
crystal run examples/block_kit_home.cr
crystal run examples/received_blocks.cr
```

Events, interactions, and commands ([guide](documentation/events-and-interactions.md#examples)):

```sh
crystal run examples/event_delivery.cr
crystal run examples/event_catalog.cr
crystal run examples/assistant_events.cr
crystal run examples/interaction_context.cr
crystal run examples/slash_command.cr
```

Socket Mode ([guide](documentation/socket-mode.md#examples)):

```sh
crystal run examples/socket_mode_protocol.cr
crystal run examples/socket_mode_client.cr
crystal run examples/socket_mode_app.cr
```

App framework ([guide](documentation/app.md#examples)):

```sh
crystal run examples/app.cr
crystal run examples/custom_step.cr
crystal run examples/assistant.cr
crystal run examples/testing.cr
```

AI apps ([guide](documentation/ai-apps.md#examples)):

```sh
crystal run examples/streaming.cr
crystal run examples/plan.cr
crystal run examples/assistant_thread.cr
```

Workflow steps ([guide](documentation/workflows.md#example)):

```sh
crystal run examples/workflow_step.cr
```

A separate demo app is at [hirobot.app](https://github.com/the-business-factory/hirobot.app).

## Contributing

Run `shards install`, then `bin/check` before a pull request. `bin/check` runs `crystal tool format --check`, Ameba, and `crystal spec`. `bin/check --fix` formats the code and applies Ameba autocorrections first. Use `scripts/spec` to run only the specs. Both use a compiler cache inside the checkout, so parallel work in other checkouts does not disturb it. Tests run offline with synthetic credentials. See [test instructions](spec/support/README.md) for the few checks that start child processes.

Contributors: [Rob Cole](https://github.com/robcole) and [Alex Piechowski](https://github.com/grepsedawk).
