# Schedules a message to post later.
# See https://docs.slack.dev/reference/methods/chat.scheduleMessage.
#
# Each constructor takes one kind of content: a Block Kit `message`, plain
# `text`, or `markdown_text`, as in `ChatPostMessage`. Slack sends *post_at* as
# Unix seconds, accepts times up to 120 days ahead, and allows 30 scheduled
# messages per channel in 5 minutes. Slack checks the time (`time_in_past`,
# `time_too_far`); this request does not read the clock.
#
# There is no `metadata` field: Slack documents that a scheduled message with
# metadata does not post.
#
# ```
# request = Slack::Api::ChatScheduleMessage.new(channel: "C123", post_at: Time.utc + 1.hour, text: "Standup")
# client.call(request).scheduled_message_id
# ```
struct Slack::Api::ChatScheduleMessage < Slack::Api::Request(Slack::Models::Chat::ScheduleMessage)
  include Slack::Api::JsonBody

  @content : Slack::Api::ChatContent

  getter channel : String
  getter post_at : Time
  getter thread_ts : String?
  getter reply_broadcast : Bool?
  getter parse : Slack::Api::ChatPostMessage::Parse?
  getter link_names : Bool?
  getter unfurl_links : Bool?
  getter unfurl_media : Bool?
  getter as_user : Bool?

  # Schedules Block Kit blocks with the message's fallback text.
  def initialize(*, @channel : String, @post_at : Time, message : Slack::UI::Message,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @reply_broadcast : Bool? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @unfurl_links : Bool? = nil, @unfurl_media : Bool? = nil,
                 @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(message: message, attachments: attachments)
  end

  # Schedules plain text.
  def initialize(*, @channel : String, @post_at : Time, text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @reply_broadcast : Bool? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @unfurl_links : Bool? = nil, @unfurl_media : Bool? = nil,
                 @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(text: text, attachments: attachments)
  end

  # Schedules standard Markdown, up to 12,000 characters, without `text` or `blocks`.
  def initialize(*, @channel : String, @post_at : Time, markdown_text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @reply_broadcast : Bool? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @unfurl_links : Bool? = nil, @unfurl_media : Bool? = nil,
                 @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(markdown_text: markdown_text, attachments: attachments)
  end

  def message : Slack::UI::Message?
    @content.message
  end

  def text : String?
    @content.text
  end

  def markdown_text : String?
    @content.markdown_text
  end

  def attachments : Array(Slack::UI::Attachment)?
    @content.attachments
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @content.validate("chat_schedule_message")
    Slack::Api::ChatChecks.blank_issue(issues, "chat_schedule_message", "channel", @channel, "Channel")
    Slack::Api::ChatChecks.timestamp_issue(issues, "chat_schedule_message", "thread_ts", @thread_ts)
    Slack::Api::ChatChecks.broadcast_issue(issues, "chat_schedule_message", @reply_broadcast, @thread_ts)
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "post_at", @post_at.to_unix
      @content.fields(json)
      json.field "thread_ts", @thread_ts if @thread_ts
      json.field "reply_broadcast", @reply_broadcast unless @reply_broadcast.nil?
      if parse = @parse
        json.field "parse", parse.wire_value
      end
      json.field "link_names", @link_names unless @link_names.nil?
      json.field "unfurl_links", @unfurl_links unless @unfurl_links.nil?
      json.field "unfurl_media", @unfurl_media unless @unfurl_media.nil?
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def method_path : String
    "chat.scheduleMessage"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end
end
