# slack.cr

Crystal client for building Slack apps and tools using the Slack API.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     slack:
       github: the-business-factory/slack.cr
   ```

2. Run `shards install`

## Usage

### Configuration

```crystal
Slack.configure do |config|
  config.app_scopes = ["incoming-webhook"] # Array(String)
  config.client_id = ENV["SLACK_CLIENT_ID"] # String
  config.client_secret = ENV["SLACK_CLIENT_SECRET"] # String
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"] # String
  config.signing_secret_version = "v0" # String
  config.webhook_delivery_time_limit = 5.minutes # Time::Span
end
```

### Processing Webhooks
```crystal
require "slack"

def process_request(request : HTTP::Request)
  event_payload = Slack.process_request(event)
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

### OAuth Configuration (Optional)
slack.cr comes bundled with handling of Slack OAuth flow, allowing the use of tokens for web and other API calls.

```crystal
Slack::AuthHandler.configure do |config|
  config.oauth_redirect_url = ENV["OAUTH_REDIRECT_URL"]
end
```

```crystal
# Simple Example from a small Lucky app
require "slack/oauth"
class SlackAuth < BrowserAction
  include Auth::AllowGuests

  get "/slack/auth" do
    # auth_response : Slack::AuthResponse
    auth_response = Slack::AuthHandler.run(request)

    SaveSlackAccessToken.create!(
      slack_team_id: auth_response.team.id,
      slack_team_name: auth_response.team.name,
      token: auth_response.access_token,
      json_body: JSON.parse(auth_response.to_json)
    )

    # Normally you'd want to do something else here, like redirect...
    json({ ok: true })
  end
end
```

### Web API calls
```crystal
# Continuing our example Lucky app... on webhook receipt, this calls the API
# to get data that isn't in the webhook body.
class SlackWebhookEvent < WebhookAction
  post "/slack/webhook_events" do
    event_payload = Slack.process_request(request)
    case event_payload
    when .is_a?(Slack::UrlVerification)
      json(event_payload.response)
    else
      handle_event(event_payload.event)
      json({ok: true})
    end
  end

  def handle_event(message : Slack::Events::Message)
    auth_token = SlackAccessTokenQuery
      .new
      .slack_team_id(message.team)
      .created_at
      .desc_order
      .first

    channel_id = message.channel.not_nil!
    token = auth_token.token

    # channel : Slack::Api::Channel
    channel = Slack::Api::ConversationsInfo.new(token, channel_id).call

    # Typically you'd do something more useful than this.
    Log.info { "Channel Name: #{channel.name}" }
  end
end
```

### Other Examples
[Using Lucky Web Framework](examples/lucky.md)

## Contributing

1. Fork it (<https://github.com/the-business-factory/slack.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Rob Cole](https://github.com/robcole) - creator and maintainer
- [Alex Piechowski](https://github.com/grepsedawk) - maintainer
