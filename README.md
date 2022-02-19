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
# Any events delivered after the cutoff established by
# webhook_delivery_time_limit will be treated as too old / potential
# "Replay Attacks." See the Slack Documentation on the Events API for more info.
Slack.configure do |config|
  config.signing_secret = ENV["SLACK_SIGNING_SECRET"]
  config.webhook_delivery_time_limit = 5.minutes
end
```

### Getting Started
```crystal
require "slack"

def process_request(request : HTTP::Request)
  event_payload = Slack.process_request(event)
  case event_payload
  when .is_a?(Slack::UrlVerificationEvent)
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
