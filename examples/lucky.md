### [Example Using Lucky Web Framework](https://luckyframework.org)
```crystal
class SlackEvent < BaseModel
  include JSON::Serializable

  table do
    column data : JSON::Any
    column type : String
    column subtype : String?
  end
end
```

```
class SaveSlackEvent < SlackEvent::SaveOperation
  permit_columns data
end
```

```
abstract class WebhookAction < Lucky::Action
  disable_cookies
  accepted_formats [:json]
  include Lucky::EnforceUnderscoredRoute
end
```

```
class Api::SlackEvents::Create < WebhookAction
  post "/api/slack_events" do
    event_payload = Slack.process_request(event)
    case event_payload
    when .is_a?(Slack::UrlVerificationEvent)
      json(event_payload.response.to_json)
    else
      save_event!(event_payload.event, request.body.to_s)
      handle_event(event_payload.event)
    end
  end

  def handle_event(message : Slack::Events::Message)
    # Add your Slack App's business logic for how you'd handle a specific event,
    # etc.
  end

  def handle_event(message : Slack::Events::MessageSubtype)
    # Or you can use unions to discriminate between groups of events, and use
    # any methods that are common amongst all subtypes.
  end

  def handle_event(message : Slack::Events::AppUninstalled)
    # ... you get the point
  end

  def handle_event(unknown_event)
    Log.info { "Unhandled Event: #{unknown_event}" }
  end

  private def save_event!(event : Slack::Events::MessageSubtype, body : String)
    SaveSlackEvent.create!(
      data: JSON.parse(body),
      type: event.type,
      subtype: event.subtype,
    )
  end

  private def save_event!(event, body : String)
    SaveSlackEvent.create!(
      data: JSON.parse(body),
      type: event.type,
    )
  end
end
```
