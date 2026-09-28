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
```

The examples show checked message construction, a signed button and form submission, Home publishing and state, static selections, overflow menus, checkbox selections, radio selections, user assignments and reviewers, message status updates, and modal updates and pushes. A separate demo app is at [hirobot.app](https://github.com/the-business-factory/hirobot.app).

## Contributing

Run `shards install`, `crystal spec`, `crystal tool format --check`, and `crystal run lib/ameba/src/cli.cr --no-color` before a pull request. Tests run offline with synthetic credentials. See [test instructions](spec/support/README.md) for the few checks that start child processes.

Contributors: [Rob Cole](https://github.com/robcole) and [Alex Piechowski](https://github.com/grepsedawk).
