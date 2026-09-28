# slack.cr

Crystal client for Slack Web API calls, signed requests, OAuth app installation, and Block Kit. Requires Crystal 1.21.0 or later.

## Installation

Add the shard to `shard.yml`:

```yaml
dependencies:
  slack:
    github: the-business-factory/slack.cr
```

Run `shards install` and use the full library with `require "slack"`.

## Web API quickstart

Create one `Slack::Api::Client` with a token. Send typed requests with `call`. The token must have the scope that each Slack method requires. For example, a bot token with `team:read` can request team information:

```crystal
require "slack"

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
team = client.call(Slack::Api::TeamInfo.new)
puts team.name
```

A method without a typed request is available through the generic call. It sends form fields and returns the raw JSON. Strings are sent unchanged; other values are sent as JSON text:

```crystal
emoji = client.call("emoji.list", {include_categories: true})
emoji["emoji"].as_h.size
```

An unsuccessful result raises `Slack::Api::Error`. `code` is Slack's error name, such as `channel_not_found`, and `messages` holds `response_metadata.messages`. HTTP 429 raises `Slack::Api::RateLimited`, with `retry_after` from the `Retry-After` header. The error message never contains the response body, headers, or token.

The client paces each method locally at its documented [rate limit tier](https://docs.slack.dev/apis/web-api/rate-limits) and makes exactly one attempt. It does not retry. Local pacing does not guarantee that Slack accepts the call. API calls use `https://slack.com/api/` by default. Pass `configuration:` and `transport:` to the client to change this; see [authentication and transport](documentation/authentication.md).

To upload a file or share a remote file, see [files](documentation/files.md). `Slack::Api::FileUpload` runs the three-step upload flow and keeps the file in memory.

| Feature | Credentials and setup |
| --- | --- |
| Build or inspect Block Kit values | None. |
| Direct Web API request | Token with the method's required scopes. |
| Signed Events API, command, or interaction HTTP request | App signing secret for verification. A valid timestamp prevents stale requests; the application handles duplicate deliveries. |
| OAuth app installation | Client ID, client secret, redirect URI, bot/user scopes, trusted session binding, state store, and application-owned installation store. Pass scopes to `AuthHandler`, not global settings. |
| Stored credential dispatch and rotation | Installation store; rotating grants also need the OAuth token endpoint and client credentials. |

Global `Slack.configure` settings for webhook signing and API transport do not configure `AuthHandler`. Create it with an explicit `Slack::Auth::OAuthConfiguration`. [Authentication](documentation/authentication.md) covers installation, request authorization, rotation, revocation, storage, and transport.

Sign in with Slack is unavailable as a verified login. `Slack::SignInWithSlack` does not verify OIDC identity and raises `Slack::SignInResponse::VerificationUnavailable` on that path. Keep login separate from app installation.

### Read all pages

List methods return one page at a time. `each_page` sends a paginated request, yields each `Slack::Api::Page`, and sends the request again with the page's `next_cursor`. It stops when Slack returns an empty, null, or missing cursor. Break from the block to stop early:

```crystal
request = Slack::Api::ConversationsList.new(
  types: [Slack::Api::ConversationType::PublicChannel, Slack::Api::ConversationType::PrivateChannel],
  exclude_archived: true, limit: 200)
client.each_page(request) do |page|
  page.model.channels.each { |channel| puts channel.id }
end
```

Paginated requests are `ConversationsList`, `ConversationsHistory`, `ConversationsReplies`, and `ConversationsMembers`. Each accepts `cursor:` and `limit:`. The client rejects a `limit` outside 1 to 1000 before it sends the request; Slack checks lower method maximums. Slack recommends 100 to 200 items per page. `ConversationsInfo` reads one conversation, with optional `include_locale:` and `include_num_members:`. Conversations read as `PublicChannel`, `PrivateChannel` (also group direct messages), or `IMChat`.

Each page is one call: local pacing applies, and an error such as `RateLimited` raises from the loop. The client does not wait and retry. Since 2025-05-29, Slack limits `conversations.history` and `conversations.replies` to one request per minute and 15 items per page for new apps distributed outside the Slack Marketplace. The client does not enforce this limit. See [pagination](https://docs.slack.dev/apis/web-api/pagination) and [rate limits](https://docs.slack.dev/apis/web-api/rate-limits).

## Block Kit

Block Kit values validate supported fields and surface placement when built. Constructing them needs no credentials:

```crystal
require "slack"

alias UI = Slack::UI
message = UI.message(fallback_text: "Request 42 needs approval.") do |builder|
  builder.section(UI.mrkdwn("*Request 42* needs approval"))
  builder.actions(elements: [
    UI::BlockElements::Button.new(
      text: UI.plain("Approve"),
      action_id: "request.approve",
      value: "42",
      accessibility_label: "Approve request 42"
    ),
  ])
end

client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"])
response = client.call(Slack::Api::ChatPostMessage.new(
  channel: ENV["SLACK_CHANNEL_ID"],
  message: message
))
```

The send requires a bot token with `chat:write` and a channel the app can post to. Use `message.to_pretty_json` to inspect the payload locally. See [Block Kit](documentation/block-kit.md) for supported blocks, messages, modals, Home, static choices, incoming actions, and validation.

## Events API payloads

`Slack.process_webhook` verifies the signed request and returns `Slack::UrlVerification` or `Slack::VerifiedEvent`. The inner `event` is a typed struct for mapped types. An event type that the library does not map decodes as `Slack::Events::Unknown`: `type` gives the event type and `raw` keeps the complete event JSON. Match `Unknown` explicitly. Do not log `raw`: it can hold credentials, such as a workflow `bot_access_token`. A `message` event with a subtype that the library does not map still raises `JSON::SerializableError`.

```crystal
envelope = Slack.process_webhook(request)
if envelope.is_a?(Slack::VerifiedEvent)
  delivery = Slack::Events::Delivery.from_headers(request.headers)
  case event = envelope.event
  when Slack::Events::AppMentioned then reply(event)
  when Slack::Events::Unknown      then log("Skipped #{event.type} #{envelope.event_id}")
  end
  # delivery.retry_num (1 to 3) and delivery.retry_reason ("http_timeout", ...) are nil on the first delivery.
end
```

The envelope also gives `is_ext_shared_channel`, `context_team_id`, `context_enterprise_id`, and `event_context`. Each is nil when Slack omits it.

Slack retries a delivery up to three times when the app does not return HTTP 2xx within three seconds. To stop retries for a failed delivery, add `Slack::Events::Delivery::NO_RETRY_HEADER` with `NO_RETRY_VALUE` (`X-Slack-No-Retry: 1`) to the non-2xx response. The library does not send responses or remove duplicate deliveries; use `event_id` for that. The offline specs do not prove Slack retry timing or behavior.

## Socket Mode

Receive events, interactions, and slash commands over a WebSocket. The client gets the URL with an app-level token (`xapp-`), acknowledges through the `Acknowledger`, and reconnects when Slack refreshes the connection.

```crystal
require "slack"

client = Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])
client.run do |envelope, ack|
  ack.ack
  puts envelope.command.text if envelope.kind.slash_commands?
end
```

To decode frames without a connection, use `Slack::SocketMode::Frame.parse` and `Slack::SocketMode::Acknowledgment`. See [Socket Mode](documentation/socket-mode.md) for the connection lifecycle, frame types, payload decoding, and acknowledgment payloads.

## Slash commands and response URLs

Verify a slash command, then answer it in the HTTP 200 body. Post later replies to its `response_url`.

```crystal
command = Slack.process_command(request)
body = Slack::Commands::Response.new(text: "Deploy started.").to_json
# {"response_type":"ephemeral","text":"Deploy started."}

later = Slack::Interactions::ResponseUrlMessage.new(text: "Deploy finished.", replace_original: true)
Slack::Interactions::ResponseUrlResponder.new(command.response_url).post(Slack::Auth::HTTPTransport.new, later)
```

A `response_url` accepts five posts within 30 minutes. See [Respond to a slash command](documentation/block-kit.md#respond-to-a-slash-command).

## Workflow steps

A custom function in the app manifest is a workflow step. When a workflow runs the step, Slack sends a `function_executed` event. Read the inputs, then complete or fail the execution with the event's `bot_access_token`:

```crystal
if (event = envelope.event).is_a?(Slack::Events::FunctionExecuted)
  client = Slack::Api::Client.new(token: event.bot_access_token)
  client.call(Slack::Api::FunctionsCompleteSuccess.new(
    function_execution_id: event.function_execution_id,
    outputs: {user_id: event.inputs["user_id"].as_s}))
end
```

See [Workflow steps](documentation/workflows.md) for the manifest, inputs, and failures.

## Streaming messages

`Client#start_stream` starts a streamed message; the returned `MessageStream` appends text or task chunks and stops it. See [AI apps](documentation/ai-apps.md).

## Runnable examples

From a repository checkout, run `shards install` first. The modal, Home, and static choice examples use the development dependency WebMock. They use synthetic credentials and stub HTTP requests; they do not contact Slack.

```sh
crystal run examples/block_kit_message.cr
crystal run examples/block_kit_modal.cr
crystal run examples/block_kit_home.cr
crystal run examples/block_kit_static_select.cr
crystal run examples/block_kit_overflow.cr
crystal run examples/block_kit_checkboxes.cr
crystal run examples/block_kit_radio_buttons.cr
crystal run examples/block_kit_message_update.cr
crystal run examples/block_kit_view_update.cr
crystal run examples/block_kit_users_select.cr
crystal run examples/block_kit_view_push.cr
crystal run examples/block_kit_modal_errors.cr
crystal run examples/block_kit_modal_clear.cr
crystal run examples/block_kit_channels_select.cr
crystal run examples/block_kit_modal_push.cr
crystal run examples/block_kit_modal_update.cr
crystal run examples/block_kit_conversations_select.cr
crystal run examples/block_kit_date_time_pickers.cr
crystal run examples/block_kit_datetime_picker.cr
crystal run examples/block_kit_video.cr
crystal run examples/block_kit_external_select.cr
crystal run examples/block_kit_rich_text.cr
crystal run examples/block_kit_number_input.cr
crystal run examples/block_kit_file_input.cr
crystal run examples/block_kit_url_input.cr
crystal run examples/block_kit_email_input.cr
crystal run examples/block_kit_table.cr
crystal run examples/block_kit_context_actions.cr
crystal run examples/block_kit_data_table.cr
crystal run examples/block_kit_data_visualization.cr
crystal run examples/block_kit_card_carousel.cr
crystal run examples/block_kit_container.cr
crystal run examples/block_kit_rich_text_input.cr
crystal run examples/block_kit_markdown.cr
crystal run examples/block_kit_workflow_button.cr
crystal run examples/block_kit_alert.cr
crystal run examples/web_api.cr
crystal run examples/file_upload.cr
crystal run examples/thread_history.cr
crystal run examples/streaming.cr
crystal run examples/attachments.cr
crystal run examples/event_delivery.cr
crystal run examples/socket_mode_protocol.cr
crystal run examples/socket_mode_client.cr
crystal run examples/interaction_context.cr
crystal run examples/slash_command.cr
crystal run examples/received_blocks.cr
crystal run examples/workflow_step.cr
```

The examples show Web API calls and error codes, channel history and thread replies across cursor pages, a file upload, a remote file share, message construction, a message with a colored attachment and metadata, a signed button and form submission, Home publishing and state, static selections, overflow menus, checkbox selections, radio selections, user assignments and reviewers, external option suggestions, message status updates, modal updates and pushes, modal alerts, uploaded files, message workflow buttons, typed blocks of a received message, Socket Mode frames with their acknowledgments, a Socket Mode connection to a local server, a slash command response with a `response_url` reply, and a custom workflow step that completes or fails its execution. A separate demo app is at [hirobot.app](https://github.com/the-business-factory/hirobot.app).

## Contributing

Run `shards install`, `crystal spec`, `crystal tool format --check`, and `crystal run lib/ameba/src/cli.cr --no-color` before a pull request. Tests run offline with synthetic credentials. See [test instructions](spec/support/README.md) for the few checks that start child processes.

Contributors: [Rob Cole](https://github.com/robcole) and [Alex Piechowski](https://github.com/grepsedawk).
