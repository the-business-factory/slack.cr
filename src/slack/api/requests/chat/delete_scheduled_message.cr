# Deletes a message that is scheduled to post.
# See https://docs.slack.dev/reference/methods/chat.deleteScheduledMessage.
struct Slack::Api::ChatDeleteScheduledMessage < Slack::Api::Request(Slack::Models::DefaultResponse)
  include Slack::Api::JsonBody

  getter channel : String
  getter scheduled_message_id : String
  getter as_user : Bool?

  def initialize(*, @channel : String, @scheduled_message_id : String, @as_user : Bool? = nil)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    Slack::Api::ChatChecks.blank_issue(issues, "chat_delete_scheduled_message", "channel", @channel, "Channel")
    Slack::Api::ChatChecks.blank_issue(issues, "chat_delete_scheduled_message", "scheduled_message_id",
      @scheduled_message_id, "Scheduled message ID")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "scheduled_message_id", @scheduled_message_id
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def method_path : String
    "chat.deleteScheduledMessage"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end
end
