# Starts a streamed message. See https://docs.slack.dev/reference/methods/chat.startStream.
#
# Give `markdown_text` or `chunks`, or no content. Omit *thread_ts* (Slack's `"0"`)
# to stream a top-level message; Slack accepts that only in some channels.
# Slack requires the recipient fields when the stream is in a channel.
#
# ```
# request = Slack::Api::ChatStartStream.new(channel: "C123", thread_ts: "1721609600.000001",
#   recipient_user_id: "U123", recipient_team_id: "T123", markdown_text: "Thinking...")
# stream = client.start_stream(request)
# ```
struct Slack::Api::ChatStartStream < Slack::Api::Request(Slack::Models::Chat::StreamMessage)
  include Slack::Api::JsonBody

  @content : Streaming::Content

  getter channel : String
  getter thread_ts : String?
  getter recipient_user_id : String?
  getter recipient_team_id : String?
  getter task_display_mode : Streaming::TaskDisplayMode?
  getter username : String?
  getter icon : Slack::UI::Icon?

  def initialize(*, @channel : String, markdown_text : String? = nil, @thread_ts : String? = nil,
                 @recipient_user_id : String? = nil, @recipient_team_id : String? = nil,
                 @task_display_mode : Streaming::TaskDisplayMode? = nil, @username : String? = nil,
                 @icon : Slack::UI::Icon? = nil)
    @content = markdown_text ? Streaming::Content.new(markdown_text) : Streaming::Content.new
  end

  def initialize(*, @channel : String, chunks : Enumerable(T), @thread_ts : String? = nil,
                 @recipient_user_id : String? = nil, @recipient_team_id : String? = nil,
                 @task_display_mode : Streaming::TaskDisplayMode? = nil, @username : String? = nil,
                 @icon : Slack::UI::Icon? = nil) forall T
    @content = Streaming::Content.new(chunks)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @channel.blank?
      issues << Slack::UI::ValidationIssue.new("chat_start_stream.channel.blank", "channel", "Channel must not be blank.")
    end
    if (thread_ts = @thread_ts) && !Streaming.timestamp?(thread_ts)
      issues << Slack::UI::ValidationIssue.new("chat_start_stream.thread_ts.invalid", "thread_ts",
        "Thread timestamp must contain digits, a decimal point, and fractional digits. Use nil for a top-level stream.")
    end
    recipient_issue(issues)
    issues.concat(@content.validate("chat_start_stream"))
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "thread_ts", @thread_ts if @thread_ts
      json.field "recipient_user_id", @recipient_user_id if @recipient_user_id
      json.field "recipient_team_id", @recipient_team_id if @recipient_team_id
      if mode = @task_display_mode
        json.field "task_display_mode", mode.wire_value
      end
      json.field "username", @username if @username
      if icon = @icon
        json.field icon.wire_field, icon.value
      end
      @content.fields(json)
    end
  end

  def method_path : String
    "chat.startStream"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier2
  end

  # Slack requires both recipient fields in channels, so one without the other is always an error.
  private def recipient_issue(issues : Array(Slack::UI::ValidationIssue)) : Nil
    return if @recipient_user_id.nil? == @recipient_team_id.nil?
    path = @recipient_user_id ? "recipient_team_id" : "recipient_user_id"
    issues << Slack::UI::ValidationIssue.new("chat_start_stream.recipient.incomplete", path,
      "Recipient user ID and recipient team ID must be given together.")
  end
end
