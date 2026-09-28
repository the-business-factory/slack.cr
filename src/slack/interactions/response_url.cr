# A `response_url` that a modal submission gives for a conversation selected in
# an input with `response_url_enabled`. Slack limits each URL to five uses in
# 30 minutes; this library does not send to it.
# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/
struct Slack::Interactions::ResponseUrl
  include JSON::Serializable

  getter response_url : String
  getter block_id : String
  getter action_id : String
  getter channel_id : String

  def initialize(@response_url : String, @block_id : String, @action_id : String, @channel_id : String)
  end
end
