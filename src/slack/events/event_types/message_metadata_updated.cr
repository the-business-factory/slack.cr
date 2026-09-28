# The metadata of a message changed. Requires the `metadata.message:read` scope.
# https://docs.slack.dev/reference/events/message_metadata_updated
struct Slack::Events::MessageMetadataUpdated < Slack::Event
  getter channel_id : String
  getter message_ts : String
  getter previous_metadata : Slack::EventData::Metadata
  getter metadata : Slack::EventData::Metadata
  getter app_id : String?
  getter bot_id : String?
  getter user_id : String?
  getter event_ts : String
end
