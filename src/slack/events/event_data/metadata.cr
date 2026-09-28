# Message metadata in a `message_metadata_*` event. The payload stays raw JSON
# because the app defines its schema.
struct Slack::EventData::Metadata
  include JSON::Serializable

  getter event_type : String
  getter event_payload : JSON::Any
end
