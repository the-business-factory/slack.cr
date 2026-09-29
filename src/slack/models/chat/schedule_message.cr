# A message that Slack will post later. `message` is raw JSON: a scheduled
# message has type `delayed_message` and no `ts` yet.
struct Slack::Models::Chat::ScheduleMessage < Slack::Model
  include Slack::Api::Envelope
  getter channel : String
  getter scheduled_message_id : String
  @[JSON::Field(converter: Slack::Models::Chat::UnixTimeConverter)]
  getter post_at : Time
  getter message : JSON::Any?
end
