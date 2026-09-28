# Replaces the content of a message. See https://docs.slack.dev/reference/methods/chat.update.
#
# Each constructor takes one kind of content: a Block Kit `message`, plain
# `text`, or `markdown_text`. A Block Kit message needs explicit fallback text:
# unlike posting, omitting `text` on update keeps the old fallback. Slack keeps
# fields that the request omits: pass an empty *attachments* list to remove the
# attachments. Plain text without blocks removes the old blocks.
#
# ```
# client.call(Slack::Api::ChatUpdate.new(channel: "C123", ts: "1710000000.000100", text: "Approved"))
# ```
struct Slack::Api::ChatUpdate < Slack::Api::Request(Slack::Models::Chat::UpdateMessage)
  include Slack::Api::JsonBody

  TEXT_MAX_SIZE = 4000

  @content : Slack::Api::ChatContent
  @file_ids : Array(String)?

  getter channel : String
  getter ts : String
  getter metadata : Slack::UI::MessageMetadata?
  getter parse : Slack::Api::ChatPostMessage::Parse?
  getter link_names : Bool?
  getter reply_broadcast : Bool?
  getter as_user : Bool?

  # Replaces the blocks and the fallback text.
  def initialize(*, @channel : String, @ts : String, message : Slack::UI::Message,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, file_ids : Enumerable(String)? = nil,
                 @metadata : Slack::UI::MessageMetadata? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @reply_broadcast : Bool? = nil, @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(message: message, attachments: attachments)
    @file_ids = file_ids.try(&.map(&.itself))
  end

  # Replaces the text. Slack removes the old blocks.
  def initialize(*, @channel : String, @ts : String, text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, file_ids : Enumerable(String)? = nil,
                 @metadata : Slack::UI::MessageMetadata? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @reply_broadcast : Bool? = nil, @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(text: text, attachments: attachments)
    @file_ids = file_ids.try(&.map(&.itself))
  end

  # Replaces the content with standard Markdown, up to 12,000 characters.
  def initialize(*, @channel : String, @ts : String, markdown_text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, file_ids : Enumerable(String)? = nil,
                 @metadata : Slack::UI::MessageMetadata? = nil, @parse : Slack::Api::ChatPostMessage::Parse? = nil,
                 @link_names : Bool? = nil, @reply_broadcast : Bool? = nil, @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(markdown_text: markdown_text, attachments: attachments)
    @file_ids = file_ids.try(&.map(&.itself))
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

  # IDs of files that Slack shares with the updated message.
  def file_ids : Array(String)?
    @file_ids.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @content.validate("chat_update")
    Slack::Api::ChatChecks.blank_issue(issues, "chat_update", "channel", @channel, "Channel")
    unless Slack::Api::ChatChecks.timestamp?(@ts)
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.ts.invalid", "ts", "Message timestamp must contain digits, a decimal point, and fractional digits.")
    end
    fallback_issue(issues)
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "ts", @ts
      @content.fields(json)
      json.field "metadata", @metadata if @metadata
      if parse = @parse
        json.field "parse", parse.wire_value
      end
      json.field "link_names", @link_names unless @link_names.nil?
      json.field "reply_broadcast", @reply_broadcast unless @reply_broadcast.nil?
      json.field "file_ids", @file_ids if @file_ids
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def method_path : String
    "chat.update"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier3
  end

  private def fallback_issue(issues : Array(Slack::UI::ValidationIssue)) : Nil
    return if @content.markdown_text

    if text = @content.fallback_text
      if text.size > TEXT_MAX_SIZE
        issues << Slack::UI::ValidationIssue.new(
          "chat_update.text.too_long", "text", "Update text cannot exceed #{TEXT_MAX_SIZE} characters.")
      end
    else
      # Unlike posting, omitting text on update does not promise a new fallback.
      issues << Slack::UI::ValidationIssue.new(
        "chat_update.text.required", "text", "Message updates require explicit fallback text.")
    end
  end
end
