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

Supply a token with the scope required by the Slack method you call. For example, a bot token with `team:read` can request team information:

```crystal
require "slack"

token : String = ENV["SLACK_BOT_TOKEN"]
team = Slack::Api::TeamInfo.new(token: token).call
puts team.name
```

Slack API error responses raise `Slack::Api::Error`. API calls use `https://slack.com/api/` by default. Endpoint constructors accept named `configuration` and `transport` options where supported; see [authentication and transport](documentation/authentication.md).

| Feature | Credentials and setup |
| --- | --- |
| Build or inspect checked Block Kit values | None. |
| Direct Web API request | Token with the method's required scopes. |
| Signed Events API, command, or interaction HTTP request | App signing secret for verification. A valid timestamp prevents stale requests; the application handles duplicate deliveries. |
| OAuth app installation | Client ID, client secret, redirect URI, bot/user scopes, trusted session binding, state store, and application-owned installation store. Pass scopes to `AuthHandler`, not global settings. |
| Stored credential dispatch and rotation | Installation store; rotating grants also need the OAuth token endpoint and client credentials. |

Global `Slack.configure` settings for webhook signing and API transport do not configure `AuthHandler`. Create it with an explicit `Slack::Auth::OAuthConfiguration`. [Authentication](documentation/authentication.md) covers installation, request authorization, rotation, revocation, storage, and transport.

Sign in with Slack is unavailable as a verified login. `Slack::SignInWithSlack` does not verify OIDC identity and raises `Slack::SignInResponse::VerificationUnavailable` on that path. Keep login separate from app installation.

## Checked Block Kit

Checked values validate supported fields and surface placement when built. Constructing them needs no credentials:

```crystal
require "slack"

alias UI = Slack::UI::Checked
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

request = Slack::Api::CheckedChatPostMessage.new(
  token: ENV["SLACK_BOT_TOKEN"],
  channel: ENV["SLACK_CHANNEL_ID"],
  message: message
)
response = request.call
```

The send requires a bot token with `chat:write` and a channel the app can post to. Use `message.to_pretty_json` to inspect the payload locally. See [Block Kit](documentation/block-kit.md) for supported blocks, messages, modals, Home, static choices, incoming actions, and validation.

## Events API payloads

`Slack.process_webhook` verifies the signed request and returns `Slack::UrlVerification` or `Slack::VerifiedEvent`. The inner `event` is a typed struct for mapped types. An event type that the library does not map decodes as `Slack::Events::Unknown`: `type` gives the event type and `raw` keeps the complete event JSON. Match `Unknown` explicitly. Do not log `raw`: it can hold credentials, for example `bot_access_token` in `function_executed`. A `message` event with a subtype that the library does not map still raises `JSON::SerializableError`.

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
crystal run examples/event_delivery.cr
```

The examples show checked message construction, a signed button and form submission, Home publishing and state, static selections, overflow menus, checkbox selections, radio selections, user assignments and reviewers, external option suggestions, message status updates, modal updates and pushes, modal alerts, uploaded files, and message workflow buttons. A separate demo app is at [hirobot.app](https://github.com/the-business-factory/hirobot.app).

## Contributing

Run `shards install`, `crystal spec`, `crystal tool format --check`, and `crystal run lib/ameba/src/cli.cr --no-color` before a pull request. Tests run offline with synthetic credentials. See [test instructions](spec/support/README.md) for the few checks that start child processes.

Contributors: [Rob Cole](https://github.com/robcole) and [Alex Piechowski](https://github.com/grepsedawk).
