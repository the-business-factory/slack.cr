# Posts a message. See https://docs.slack.dev/reference/methods/chat.postMessage.
#
# Each constructor takes one kind of content: a Block Kit `message`, plain
# `text`, or `markdown_text`. Slack rejects `markdown_text` together with `text`
# or `blocks` (`markdown_text_conflict`), so no constructor accepts both.
# Attachments go with any content kind. The request copies its message,
# attachments, and metadata when you create it.
#
# `username` and `icon` need the `chat:write.customize` scope. `as_user` is a
# legacy argument for classic apps.
struct Slack::Api::ChatPostMessage < Slack::Api::Request(Slack::Models::Chat::PostMessage)
  include Slack::Api::JsonBody

  ATTACHMENTS_MAX_SIZE   = Slack::Api::ChatContent::ATTACHMENTS_MAX_SIZE
  MARKDOWN_TEXT_MAX_SIZE = Slack::Api::ChatContent::MARKDOWN_TEXT_MAX_SIZE

  # How Slack parses `text`: `full` links names and URLs, `none` does not.
  enum Parse
    None
    Full

    def wire_value : String
      case self
      in .none? then "none"
      in .full? then "full"
      end
    end
  end

  @content : Slack::Api::ChatContent

  getter channel : String
  getter thread_ts : String?
  getter reply_broadcast : Bool?
  getter metadata : Slack::UI::MessageMetadata?
  getter mrkdwn : Bool?
  getter parse : Parse?
  getter link_names : Bool?
  getter unfurl_links : Bool?
  getter unfurl_media : Bool?
  getter unfurl_app_links : Bool?
  getter username : String?
  getter icon : Slack::UI::Icon?
  getter as_user : Bool?

  # Posts Block Kit blocks with the message's fallback text.
  def initialize(
    *,
    @channel : String,
    message : Slack::UI::Message,
    attachments : Enumerable(Slack::UI::Attachment)? = nil,
    @thread_ts : String? = nil,
    @reply_broadcast : Bool? = nil,
    @metadata : Slack::UI::MessageMetadata? = nil,
    @mrkdwn : Bool? = nil,
    @parse : Parse? = nil,
    @link_names : Bool? = nil,
    @unfurl_links : Bool? = nil,
    @unfurl_media : Bool? = nil,
    @unfurl_app_links : Bool? = nil,
    @username : String? = nil,
    @icon : Slack::UI::Icon? = nil,
    @as_user : Bool? = nil,
  )
    @content = Slack::Api::ChatContent.new(message: message, attachments: attachments)
  end

  # Posts plain text. Slack formats it as `mrkdwn` unless `mrkdwn` is false.
  def initialize(
    *,
    @channel : String,
    text : String,
    attachments : Enumerable(Slack::UI::Attachment)? = nil,
    @thread_ts : String? = nil,
    @reply_broadcast : Bool? = nil,
    @metadata : Slack::UI::MessageMetadata? = nil,
    @mrkdwn : Bool? = nil,
    @parse : Parse? = nil,
    @link_names : Bool? = nil,
    @unfurl_links : Bool? = nil,
    @unfurl_media : Bool? = nil,
    @unfurl_app_links : Bool? = nil,
    @username : String? = nil,
    @icon : Slack::UI::Icon? = nil,
    @as_user : Bool? = nil,
  )
    @content = Slack::Api::ChatContent.new(text: text, attachments: attachments)
  end

  # Posts standard Markdown, up to 12,000 characters, without `text` or `blocks`.
  def initialize(
    *,
    @channel : String,
    markdown_text : String,
    attachments : Enumerable(Slack::UI::Attachment)? = nil,
    @thread_ts : String? = nil,
    @reply_broadcast : Bool? = nil,
    @metadata : Slack::UI::MessageMetadata? = nil,
    @mrkdwn : Bool? = nil,
    @parse : Parse? = nil,
    @link_names : Bool? = nil,
    @unfurl_links : Bool? = nil,
    @unfurl_media : Bool? = nil,
    @unfurl_app_links : Bool? = nil,
    @username : String? = nil,
    @icon : Slack::UI::Icon? = nil,
    @as_user : Bool? = nil,
  )
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
    issues = @content.validate("chat_post_message")
    if @channel.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "chat_post_message.channel.empty",
        path: "channel",
        message: "Channel must not be empty."
      )
    end
    Slack::Api::FieldChecks.timestamp_issue(issues, "chat_post_message", "thread_ts", @thread_ts)
    Slack::Api::ChatChecks.broadcast_issue(issues, "chat_post_message", @reply_broadcast, @thread_ts)
    Slack::Api::FieldChecks.blank_issue(issues, "chat_post_message", "username", @username, "Username")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      @content.fields(json)
      json.field "thread_ts", @thread_ts if @thread_ts
      json.field "reply_broadcast", @reply_broadcast unless @reply_broadcast.nil?
      json.field "metadata", @metadata if @metadata
      formatting_to_json(json)
      sender_to_json(json)
    end
  end

  def method_path : String
    "chat.postMessage"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Special
  end

  private def formatting_to_json(json : JSON::Builder) : Nil
    json.field "mrkdwn", @mrkdwn unless @mrkdwn.nil?
    if parse = @parse
      json.field "parse", parse.wire_value
    end
    json.field "link_names", @link_names unless @link_names.nil?
    json.field "unfurl_links", @unfurl_links unless @unfurl_links.nil?
    json.field "unfurl_media", @unfurl_media unless @unfurl_media.nil?
    json.field "unfurl_app_links", @unfurl_app_links unless @unfurl_app_links.nil?
  end

  private def sender_to_json(json : JSON::Builder) : Nil
    json.field "username", @username if @username
    if icon = @icon
      json.field icon.wire_field, icon.value
    end
    json.field "as_user", @as_user unless @as_user.nil?
  end
end
