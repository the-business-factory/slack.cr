# Posts a copied, validated message. See https://docs.slack.dev/reference/methods/chat.postMessage.
struct Slack::Api::ChatPostMessage < Slack::Api::Request(Slack::Models::Chat::PostMessage)
  include Slack::Api::JsonBody

  @snapshot : Slack::UI::Message

  getter channel : String
  getter thread_ts : String?
  getter reply_broadcast : Bool?
  getter unfurl_links : Bool?
  getter unfurl_media : Bool?

  def initialize(
    @channel : String,
    message : Slack::UI::Message,
    @thread_ts : String? = nil,
    @reply_broadcast : Bool? = nil,
    @unfurl_links : Bool? = nil,
    @unfurl_media : Bool? = nil,
  )
    @snapshot = message.snapshot
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @snapshot.validate
    if @channel.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "chat_post_message.channel.empty",
        path: "channel",
        message: "Channel must not be empty."
      )
    end
    if timestamp = @thread_ts
      # Slack ts values contain epoch seconds and a fraction. Check only their
      # shape: fixed digit counts are not documented, and Float loses precision.
      # https://docs.slack.dev/changelog/2016/05/31/more-events-timestamps-in-rtm-api/
      unless /\A[0-9]+\.[0-9]+\z/.matches?(timestamp)
        issues << Slack::UI::ValidationIssue.new(
          code: "chat_post_message.thread_ts.invalid",
          path: "thread_ts",
          message: "Thread timestamp must contain digits, a decimal point, and fractional digits."
        )
      end
    end
    if @reply_broadcast && @thread_ts.nil?
      issues << Slack::UI::ValidationIssue.new(
        code: "chat_post_message.reply_broadcast.thread_required",
        path: "reply_broadcast",
        message: "Reply broadcast requires a thread timestamp."
      )
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "text", @snapshot.fallback_text if @snapshot.fallback_text
      json.field "blocks" do
        @snapshot.blocks_to_json(json)
      end
      json.field "thread_ts", @thread_ts if @thread_ts
      json.field "reply_broadcast", @reply_broadcast unless @reply_broadcast.nil?
      json.field "unfurl_links", @unfurl_links unless @unfurl_links.nil?
      json.field "unfurl_media", @unfurl_media unless @unfurl_media.nil?
    end
  end

  def method_path : String
    "chat.postMessage"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Special
  end
end
