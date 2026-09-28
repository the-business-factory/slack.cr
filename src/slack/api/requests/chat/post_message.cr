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

  # Slack's documented maximum for one request. The attachments guide advises
  # at most 20.
  ATTACHMENTS_MAX_SIZE   =    100
  MARKDOWN_TEXT_MAX_SIZE = 12_000

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

  @message : Slack::UI::Message?
  @attachments : Array(Slack::UI::Attachment)?

  getter channel : String
  getter text : String?
  getter markdown_text : String?
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
    @message = message.snapshot
    @attachments = attachments.try(&.map(&.itself))
  end

  # Posts plain text. Slack formats it as `mrkdwn` unless `mrkdwn` is false.
  def initialize(
    *,
    @channel : String,
    @text : String,
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
    @attachments = attachments.try(&.map(&.itself))
  end

  # Posts standard Markdown, up to 12,000 characters, without `text` or `blocks`.
  def initialize(
    *,
    @channel : String,
    @markdown_text : String,
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
    @attachments = attachments.try(&.map(&.itself))
  end

  def message : Slack::UI::Message?
    @message.try(&.snapshot)
  end

  def attachments : Array(Slack::UI::Attachment)?
    @attachments.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @message.try(&.validate) || [] of Slack::UI::ValidationIssue
    if @channel.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "chat_post_message.channel.empty",
        path: "channel",
        message: "Channel must not be empty."
      )
    end
    text_issues(issues)
    thread_issues(issues)
    attachment_issues(issues)
    if username = @username
      if username.blank?
        issues << Slack::UI::ValidationIssue.new(
          "chat_post_message.username.blank", "username", "Username must not be blank.")
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "channel", @channel
      content_to_json(json)
      json.field "attachments", @attachments if @attachments
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

  private def content_to_json(json : JSON::Builder) : Nil
    if message = @message
      json.field "text", message.fallback_text if message.fallback_text
      json.field("blocks") { message.blocks_to_json(json) }
    end
    json.field "text", @text if @text
    json.field "markdown_text", @markdown_text if @markdown_text
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

  private def text_issues(issues : Array(Slack::UI::ValidationIssue)) : Nil
    if @text.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new(
        "chat_post_message.text.empty", "text", "Text must not be empty.")
    end
    return unless markdown_text = @markdown_text

    if markdown_text.empty?
      issues << Slack::UI::ValidationIssue.new(
        "chat_post_message.markdown_text.empty", "markdown_text", "Markdown text must not be empty.")
    elsif markdown_text.size > MARKDOWN_TEXT_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        "chat_post_message.markdown_text.too_long", "markdown_text",
        "Markdown text cannot exceed #{MARKDOWN_TEXT_MAX_SIZE} characters.")
    end
  end

  private def thread_issues(issues : Array(Slack::UI::ValidationIssue)) : Nil
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
  end

  private def attachment_issues(issues : Array(Slack::UI::ValidationIssue)) : Nil
    return unless attachments = @attachments

    if attachments.size > ATTACHMENTS_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        "chat_post_message.attachments.too_many", "attachments",
        "A message cannot contain more than #{ATTACHMENTS_MAX_SIZE} attachments.")
    end
    attachments.each_with_index do |attachment, index|
      issues.concat(attachment.validate.map(&.at("attachments[#{index}]")))
    end
    attached_block_issues(issues, attachments)
  end

  # Block IDs are unique in the whole message, and Slack limits the Markdown
  # block text of the whole payload. Each Message and Attachment checks its own
  # blocks; this checks what spans them, so no issue is reported twice.
  private def attached_block_issues(issues : Array(Slack::UI::ValidationIssue),
                                    attachments : Array(Slack::UI::Attachment)) : Nil
    groups = [] of {String, Array(Slack::UI::MessageBlock)}
    @message.try { |message| groups << {"", message.blocks} }
    attachments.each_with_index do |attachment, index|
      attachment.blocks.try { |blocks| groups << {"attachments[#{index}].", blocks} }
    end
    duplicate_block_id_issues(issues, groups)
    combined_markdown_issue(issues, groups)
  end

  private def duplicate_block_id_issues(issues : Array(Slack::UI::ValidationIssue),
                                        groups : Array({String, Array(Slack::UI::MessageBlock)})) : Nil
    earlier = Set(String).new
    groups.each do |prefix, blocks|
      current = Set(String).new
      block_ids(blocks, prefix) do |id, path|
        if earlier.includes?(id)
          issues << Slack::UI::ValidationIssue.new(
            "chat_post_message.block_id.duplicate", path, "Block IDs must be unique within a message and its attachments.")
        end
        current << id
      end
      earlier.concat(current)
    end
  end

  private def block_ids(blocks : Array(Slack::UI::MessageBlock), prefix : String, & : String, String ->) : Nil
    blocks.each_with_index do |block, index|
      block.block_id.try { |id| yield id, "#{prefix}blocks[#{index}].block_id" }
      next unless block.is_a?(Slack::UI::Blocks::Container)

      block.child_blocks.each_with_index do |child, position|
        child.block_id.try { |id| yield id, "#{prefix}blocks[#{index}].child_blocks[#{position}].block_id" }
      end
    end
  end

  private def combined_markdown_issue(issues : Array(Slack::UI::ValidationIssue),
                                      groups : Array({String, Array(Slack::UI::MessageBlock)})) : Nil
    sizes = groups.map { |_, blocks| blocks.sum { |block| block.is_a?(Slack::UI::Blocks::Markdown) ? block.text.size : 0 } }
    limit = Slack::UI::Blocks::Markdown::TEXT_MAX_SIZE
    # A single group over the limit already has its own message issue.
    return if sizes.sum <= limit || sizes.any? { |size| size > limit }

    issues << Slack::UI::ValidationIssue.new(
      "chat_post_message.markdown.too_long", "attachments",
      "The markdown blocks in a message and its attachments cannot contain more than #{limit} characters in total.")
  end
end
