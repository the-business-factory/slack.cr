# slack.cr

Crystal client for building Slack apps and tools using the Slack API.

Requires Crystal 1.21.0 or later.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     slack:
       github: the-business-factory/slack.cr
   ```

2. Run `shards install`

## Usage

## Demo App

A demo app is published at https://github.com/the-business-factory/hirobot.app.

### Configuration

```crystal
require "slack"

Slack.configure do |config|
  config.bot_scopes = ["incoming-webhook"] # Array(String)
  config.client_id = ENV["SLACK_CLIENT_ID"] # String?
  config.client_secret = ENV["SLACK_CLIENT_SECRET"] # String?
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"] # String?
  config.signing_secret_version = "v0" # String
  config.webhook_delivery_time_limit = 5.minutes # Time::Span
end

```

`require "slack"` loads the core and OAuth installation APIs. The compatibility
entrypoint `require "slack/oauth"` loads the same APIs. Either require order is supported.

### OAuth installation

`Slack::AuthHandler` handles app installation; it does not authenticate a login. Create it
with an explicit `Slack::Auth::OAuthConfiguration`, `Slack::Auth::StateStore`, and
`Slack::Auth::Transport`. Pass a trusted application session binding to both handler
methods. The handler does not read that value from callback parameters or cookies.

See [OAuth installation](documentation/oauth-installation.md) for setup, routing, storage,
and migration examples. `Slack::Auth::MemoryStateStore` is for one process only. Use a
shared application-owned adapter when callbacks can reach more than one process.

### Sign in with Slack

Sign in with Slack is unavailable until full OIDC identity verification is
implemented. The class is `Slack::SignInWithSlack`. Configuration does not enable
verified login. The identity path raises
`Slack::SignInResponse::VerificationUnavailable`; do not use decoded claims as an
authenticated identity. Keep login scopes and routes separate from app installation.
No JWT dependency is required for this guard.

### Processing Webhook Events
```crystal
require "slack"

def process_webhook(request : HTTP::Request)
  event_payload = Slack.process_webhook(event)
  case event_payload
  when .is_a?(Slack::UrlVerification)
    json(event_payload.response.to_json)
  else
    handle_event(event_payload.event)
  end
end

# You can easily handle only the events you expect back, with type safety.
def handle_event(event : Slack::Event::Message::MessageChanged)
  pp event.message.text
end

# And of course sometimes, you just want to ignore things you don't expect.
def handle_event(unhandled_event)
end
```

### Web API calls

When returning responses from the Slack API, error responses are raised, rather
than returned as separate error objects. This provides strongly typed responses
for the majority of API traffic; Slack::Api::Error errors can be rescued to
allow customized error handling if needed.

API calls use `https://slack.com/api/` by default. You can set a different API
host or path and connection options without changing OAuth configuration:

```crystal
Slack.configure do |config|
  config.api_configuration = Slack::Auth::APIConfiguration.new(
    URI.parse("https://api.slack-gov.com/api/")
  )
  config.api_transport_options = Slack::Auth::TransportOptions.new(
    connect_timeout: 5.seconds,
    read_timeout: 20.seconds,
    write_timeout: 20.seconds,
    ca_file: "/etc/ssl/certs/company-ca.pem"
  )
end
```

Each API wrapper also accepts named `configuration` and `transport` arguments.
This supports request-local credentials and offline tests. See
[authentication transport](documentation/auth-transport.md) for the endpoint,
proxy, TLS, and failure rules.

```crystal
class ExampleSlackApiCall
  def initialize(@token : String, @channel_id : String)
  end

  def run
    # Guaranteed to be some sort of Slack::Model::Conversation object.
    channel = Slack::Api::ConversationsInfo.new(token, channel_id).call

    # Now you can with Slack's polymorphic API in uniform ways.
    case channel
    when Slack::Models::IMChat
      Log.info { "IM Chat Latest Message Read: #{channel.latest}" }
    when Slack::Models::PublicChannel
      Log.info { "Public Team Channel Name: #{channel.name}" }
    end
  rescue exc : Slack::Api::Error
    # exc.message will typically have the JSON Error Results from Slack's API.
    Log.info { "Error Raised: #{exc.message}" }
  end
end
```

### Checked Block Kit messages

Use `require "slack/ui"` to build and inspect messages without credentials. The
checked values are immutable. They validate Slack limits when you construct them.

```crystal
require "slack/ui"

struct RequestSummary
  def initialize(@request_id : String)
  end

  def render : Slack::UI::Checked::Blocks::Section
    Slack::UI::Checked::Blocks::Section.new(
      text: Slack::UI::Checked.mrkdwn("*Request #{@request_id}* needs approval")
    )
  end
end

message = Slack::UI::Checked.message(
  fallback_text: "Request 42 needs approval."
) do |builder|
  builder.add(RequestSummary.new("42").render)
  builder.divider
  builder.actions(elements: [
    Slack::UI::Checked::BlockElements::Button.new(
      text: Slack::UI::Checked.plain("Approve"),
      action_id: "request.approve",
      value: "42",
      accessibility_label: "Approve request 42"
    ),
  ])
end

puts message.to_pretty_json
```

Use `Slack::Api::CheckedChatPostMessage` after `require "slack"` to send the
message. Tests can inspect `request.to_json` without sending it.

```crystal
request = Slack::Api::CheckedChatPostMessage.new(
  token: token,
  channel: channel_id,
  message: message
)
response = request.call
```

The mutable Phase 1 types and component helpers remain available. See
[Block Kit Phase 2](documentation/block-kit-phase-2.md) for supported fields,
accessibility choices, and migration examples.

### Checked modals and interactions

Use `Slack::UI::Checked.form_modal` with a plain-text `title` and required
`submit` label. Its builder accepts checked Input blocks containing PlainTextInput.
Use `display_modal` for content without Input blocks. Both builders return stable
snapshots that `Slack::Api::CheckedViewsOpen` can send.

`Slack.process_interaction` keeps signature verification. For a received
`BlockAction`, use `decoded_actions` to read button IDs and values. For a
`ViewSubmission`, use `plain_text?(block_id, action_id)` to read submitted text.
Unknown values remain available as raw JSON.

Run the complete offline message-button-modal-submission example:

```sh
crystal run examples/block_kit_modal.cr
```

See [Block Kit Phase 3](documentation/block-kit-phase-3.md) for field limits,
state presence, migration, and the remaining support limits.

### Checked display blocks and Home

Use `Slack::UI::Checked.home` to build a Home view with Header, Context, images,
and plain text Input. Header, Context, and images also work in checked messages
and modals. Images require alt text and either a public URL or a checked SlackFile.
Send Home through `Slack::Api::CheckedViewsPublish`; optional dispatch settings
include `configuration`, `transport`, and `limiter`.

```sh
crystal run examples/block_kit_home.cr
```

The example publishes through an injected offline transport and reads text from
a simulated Home action. See [Block Kit Phase 4](documentation/block-kit-phase-4.md)
for fields, placement, migration, and the remaining inbound limits.

### Static choices

Use checked `CompositionObjects::Option` and `OptionGroup` with
`BlockElements::StaticSelect` or `MultiStaticSelect`. Supply `options:` or
`option_groups:`. Both variants work in Section and Actions; FormModal and Home
also accept them in Input blocks.

```sh
crystal run examples/block_kit_static_select.cr
```

This offline example posts a single select, reads a signed selection, opens a
multi-select form, and reads its signed submission. Use `decoded_actions` and
`state_map.static_select_value?` or `state_map.multi_static_select_value?` for
received selections. See the [Phase 5 static-choice slice](documentation/block-kit-phase-5-static-selects.md)
for limits, presence handling, migration, and deferred choice families.

## Development

```sh
shards install
crystal spec
crystal tool format --check
crystal run lib/ameba/src/cli.cr
```

The full suite runs offline using `.env.test`, [WebMock](https://github.com/manastech/webmock.cr)
request stubs, and committed response fixtures. WebMock rejects unstubbed external
requests, including streaming requests. Bounded transport specs use only local loopback
sockets with synthetic TLS credentials. Local `.env` files are not loaded. The response
bodies come from the repository's existing API fixtures; the manifest response uses the
dummy app ID from `.env.test`.

## Contributing

1. Fork it (<https://github.com/the-business-factory/slack.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Rob Cole](https://github.com/robcole) - creator and maintainer
- [Alex Piechowski](https://github.com/grepsedawk) - maintainer
