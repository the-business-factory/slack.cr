# A message with metadata was posted. Requires the `metadata.message:read` scope.
# https://docs.slack.dev/reference/events/message_metadata_posted
struct Slack::Events::MessageMetadataPosted < Slack::Event
  getter channel_id : String
  getter message_ts : String
  getter metadata : Slack::EventData::Metadata
  getter app_id : String?
  getter bot_id : String?
  getter user_id : String?
  getter event_ts : String
end
