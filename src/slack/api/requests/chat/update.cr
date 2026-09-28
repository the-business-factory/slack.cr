# Replaces message blocks and explicit fallback text.
# See https://docs.slack.dev/reference/methods/chat.update.
struct Slack::Api::ChatUpdate < Slack::Api::Request(Slack::Models::Chat::UpdateMessage)
  include Slack::Api::JsonBody

  @snapshot : Slack::UI::Message

  getter channel : String
  getter ts : String
  getter as_user : Bool?

  def initialize(
    @channel : String,
    @ts : String,
    message : Slack::UI::Message,
    @as_user : Bool? = nil,
  )
    @snapshot = message.snapshot
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate
    if @channel.blank?
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.channel.blank", "channel", "Channel must not be blank.")
    end
    # Keep the timestamp as a string: Slack does not promise fixed digit counts.
    unless /\A[0-9]+\.[0-9]+\z/.matches?(@ts)
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.ts.invalid", "ts", "Message timestamp must contain digits, a decimal point, and fractional digits.")
    end
    if text = @snapshot.fallback_text
      if text.size > 4000
        issues << Slack::UI::ValidationIssue.new(
          "chat_update.text.too_long", "text", "Update fallback text cannot exceed 4000 characters.")
      end
    else
      # Unlike posting, omitting text on update does not promise a new fallback.
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.text.required", "text", "Message updates require explicit fallback text.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "ts", @ts
      json.field "text", @snapshot.fallback_text
      json.field "blocks" do
        @snapshot.blocks_to_json(json)
      end
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def method_path : String
    "chat.update"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end
end
