# Posts a `/me` message, which Slack shows in italics.
# See https://docs.slack.dev/reference/methods/chat.meMessage.
struct Slack::Api::ChatMeMessage < Slack::Api::Request(Slack::Models::Chat::MeMessage)
  include Slack::Api::JsonBody

  getter channel : String
  getter text : String

  def initialize(*, @channel : String, @text : String)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    Slack::Api::FieldChecks.blank_issue(issues, "chat_me_message", "channel", @channel, "Channel")
    if @text.empty?
      issues << Slack::UI::ValidationIssue.new("chat_me_message.text.empty", "text", "Text must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "text", @text
    end
  end

  def method_path : String
    "chat.meMessage"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end
end
