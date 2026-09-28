# A message with metadata was deleted. Requires the `metadata.message:read` scope.
# https://docs.slack.dev/reference/events/message_metadata_deleted
struct Slack::Events::MessageMetadataDeleted < Slack::Event
  getter channel_id : String
  getter message_ts : String
  getter deleted_ts : String
  getter previous_metadata : Slack::EventData::Metadata
  getter app_id : String?
  getter bot_id : String?
  getter user_id : String?
  getter event_ts : String
end
