# Shows a message to one user in a conversation.
# See https://docs.slack.dev/reference/methods/chat.postEphemeral.
#
# Each constructor takes one kind of content: a Block Kit `message`, plain
# `text`, or `markdown_text`, as in `ChatPostMessage`. The user must be active
# and a member of *channel*; Slack does not guarantee delivery. The response
# `message_ts` cannot be used with `ChatUpdate`.
#
# Slack disregards event metadata on ephemeral messages, so this request has no
# `metadata`. `username` and `icon` need the `chat:write.customize` scope.
#
# ```
# client.call(Slack::Api::ChatPostEphemeral.new(channel: "C123", user: "U123", text: "Only you can see this."))
# ```
struct Slack::Api::ChatPostEphemeral < Slack::Api::Request(Slack::Models::Chat::PostEphemeral)
  include Slack::Api::JsonBody

  @content : Slack::Api::ChatContent

  getter channel : String
  getter user : String
  getter thread_ts : String?
  getter parse : Slack::Api::ChatPostMessage::Parse?
  getter link_names : Bool?
  getter username : String?
  getter icon : Slack::UI::Icon?
  getter as_user : Bool?

  # Shows Block Kit blocks with the message's fallback text.
  def initialize(*, @channel : String, @user : String, message : Slack::UI::Message,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @parse : Slack::Api::ChatPostMessage::Parse? = nil, @link_names : Bool? = nil,
                 @username : String? = nil, @icon : Slack::UI::Icon? = nil, @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(message: message, attachments: attachments)
  end

  # Shows plain text.
  def initialize(*, @channel : String, @user : String, text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @parse : Slack::Api::ChatPostMessage::Parse? = nil, @link_names : Bool? = nil,
                 @username : String? = nil, @icon : Slack::UI::Icon? = nil, @as_user : Bool? = nil)
    @content = Slack::Api::ChatContent.new(text: text, attachments: attachments)
  end

  # Shows standard Markdown, up to 12,000 characters, without `text` or `blocks`.
  def initialize(*, @channel : String, @user : String, markdown_text : String,
                 attachments : Enumerable(Slack::UI::Attachment)? = nil, @thread_ts : String? = nil,
                 @parse : Slack::Api::ChatPostMessage::Parse? = nil, @link_names : Bool? = nil,
                 @username : String? = nil, @icon : Slack::UI::Icon? = nil, @as_user : Bool? = nil)
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
    issues = @content.validate("chat_post_ephemeral")
    Slack::Api::FieldChecks.blank_issue(issues, "chat_post_ephemeral", "channel", @channel, "Channel")
    Slack::Api::FieldChecks.blank_issue(issues, "chat_post_ephemeral", "user", @user, "User")
    Slack::Api::FieldChecks.timestamp_issue(issues, "chat_post_ephemeral", "thread_ts", @thread_ts)
    Slack::Api::FieldChecks.blank_issue(issues, "chat_post_ephemeral", "username", @username, "Username")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      json.field "user", @user
      @content.fields(json)
      json.field "thread_ts", @thread_ts if @thread_ts
      if parse = @parse
        json.field "parse", parse.wire_value
      end
      json.field "link_names", @link_names unless @link_names.nil?
      json.field "username", @username if @username
      if icon = @icon
        json.field icon.wire_field, icon.value
      end
      json.field "as_user", @as_user unless @as_user.nil?
    end
  end

  def method_path : String
    "chat.postEphemeral"
  end

  def tier : Slack::Api::RateLimitTier
    Slack::Api::RateLimitTier::Tier4
  end
end
