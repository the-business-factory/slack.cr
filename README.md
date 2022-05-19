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

## Demo App

A demo app is published at https://github.com/the-business-factory/hirobot.app.

### Configuration

```crystal
Slack.configure do |config|
  config.bot_scopes = ["incoming-webhook"] # Array(String)
  config.client_id = ENV["SLACK_CLIENT_ID"] # String
  config.client_secret = ENV["SLACK_CLIENT_SECRET"] # String
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"] # String
  config.signing_secret_version = "v0" # String
  config.webhook_delivery_time_limit = 5.minutes # Time::Span
end

# Most apps will want to have OAuth enabled for installation.
Slack::AuthHandler.configure do |config|
  config.oauth_redirect_url = ENV["OAUTH_REDIRECT_URL"]
end
```

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

### Slack UI Tools
```crystal
# Users can easily define custom UI components to help build out "app specific"
# "UI Kits" fairly easily, focusing on the UX and business logic rather than
# the stupid internals of Slack's API.
struct ButtonSection < Slack::UI::CustomComponent
  include Slack::UI::BaseComponents

  def self.render(action_id : String)
    buttons = %w(Submit Cancel).map do |text|
      style = text == "Submit" ? ButtonStyles::Primary : ButtonStyles::Danger
      ButtonElement.render(
        action_id: "#{action_id}_#{text.downcase}",
        button_text: text,
        style: style
      )
    end

    Slack::UI::Blocks::Actions.new elements: buttons
  end
end

class SlackLinkPage < WebhookAction
  include Slack::UI::BaseComponents

  post "/slack/links" do
    command = Slack.process_command(request)
    text = command.text.presence || "nothing"

    text_section = TextSection.render(
      text: "processed #{command.command} with #{text} as text."
    )

    input_element = InputElement.render(
      action_id: "compensation",
      placeholder_text: "e.g. $120,000-$190,000",
      label_text: "Compensation",
      initial_value: ""
    )

    button_section = ButtonSection.render(
      action_id: "button_group_#{Random::Secure.hex}"
    )

    json({blocks: [text_section, input_element, button_section]})
  end
end
```

## Contributing

1. Fork it (<https://github.com/the-business-factory/slack.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Rob Cole](https://github.com/robcole) - creator and maintainer
- [Alex Piechowski](https://github.com/grepsedawk) - maintainer
