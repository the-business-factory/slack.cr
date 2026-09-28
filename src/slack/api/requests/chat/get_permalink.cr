require "uri"

# Reads the permanent URL of a message.
# See https://docs.slack.dev/reference/methods/chat.getPermalink.
struct Slack::Api::ChatGetPermalink < Slack::Api::Request(Slack::Models::Chat::Permalink)
  include Slack::Api::FormBody

  getter channel : String
  getter message_ts : String

  def initialize(*, @channel : String, @message_ts : String)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    Slack::Api::ChatChecks.blank_issue(issues, "chat_get_permalink", "channel", @channel, "Channel")
    Slack::Api::ChatChecks.timestamp_issue(issues, "chat_get_permalink", "message_ts", @message_ts)
    issues
  end

  def form : URI::Params
    URI::Params{"channel" => @channel, "message_ts" => @message_ts}
  end

  def method_path : String
    "chat.getPermalink"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Special
  end
end
