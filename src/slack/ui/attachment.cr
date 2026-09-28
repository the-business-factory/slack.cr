# A secondary message attachment for `Slack::Api::ChatPostMessage`.
#
# Slack recommends `blocks` with an optional `color`. The other display fields
# are legacy fields. Slack requires `fallback` or `text` when `blocks` is absent,
# and does not accept `image_url` with `thumb_url`. Blocks follow the message
# block rules; `Slack::Api::ChatPostMessage` also checks block IDs and Markdown
# block text across the message and all its attachments. Interactive legacy fields
# (`callback_id`, `actions`) are not supported.
# See https://docs.slack.dev/legacy/legacy-messaging/legacy-secondary-message-attachments.
struct Slack::UI::Attachment
  include Slack::UI::ValueValidation

  FOOTER_MAX_SIZE = 300

  # A copy of the blocks, validated with the message block rules.
  @content : Message?
  @fields : Array(Field)?
  @mrkdwn_in : Array(String)?

  getter color : Color?
  getter fallback : String?
  getter pretext : String?
  getter author_name : String?
  getter author_link : String?
  getter author_icon : String?
  getter title : String?
  getter title_link : String?
  getter text : String?
  getter image_url : String?
  getter thumb_url : String?
  getter footer : String?
  getter footer_icon : String?
  # Unix time in seconds that Slack shows beside the footer.
  getter ts : Int64?

  def initialize(
    *,
    blocks : Enumerable(T)? = nil,
    @color : Color? = nil,
    @fallback : String? = nil,
    @pretext : String? = nil,
    @author_name : String? = nil,
    @author_link : String? = nil,
    @author_icon : String? = nil,
    @title : String? = nil,
    @title_link : String? = nil,
    @text : String? = nil,
    fields : Enumerable(Field)? = nil,
    @image_url : String? = nil,
    @thumb_url : String? = nil,
    @footer : String? = nil,
    @footer_icon : String? = nil,
    @ts : Int64? = nil,
    mrkdwn_in : Enumerable(String)? = nil,
  ) forall T
    @content = blocks.try { |items| Message.with_slack_generated_fallback(items) }
    # `map` copies an Array argument; `to_a` would return the caller's Array.
    @fields = fields.try(&.map(&.itself))
    @mrkdwn_in = mrkdwn_in.try(&.map(&.itself))
    validate!
  end

  def blocks : Array(MessageBlock)?
    @content.try(&.blocks)
  end

  def fields : Array(Field)?
    @fields.try(&.dup)
  end

  # Field names that Slack formats as `mrkdwn`, for example `["text", "pretext"]`.
  def mrkdwn_in : Array(String)?
    @mrkdwn_in.try(&.dup)
  end

  def validate : Array(ValidationIssue)
    issues = @content.try(&.validate) || [] of ValidationIssue
    @color.try { |color| issues.concat(color.validate.map(&.at("color"))) }
    content_issue(issues)
    dependency_issue(issues, @author_link, @author_name, "attachment.author_link.author_name_required", "author_link", "Author link requires author name.")
    dependency_issue(issues, @author_icon, @author_name, "attachment.author_icon.author_name_required", "author_icon", "Author icon requires author name.")
    dependency_issue(issues, @footer_icon, @footer, "attachment.footer_icon.footer_required", "footer_icon", "Footer icon requires footer.")
    length_issue(issues, @footer, FOOTER_MAX_SIZE, "attachment.footer.too_long", "footer")
    if @image_url && @thumb_url
      issues << ValidationIssue.new("attachment.image_url.thumb_url_conflict", "image_url",
        "Image URL cannot be used with thumb URL.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      if color = @color
        json.field "color", color.wire_value
      end
      if content = @content
        json.field("blocks") { content.blocks_to_json(json) }
      end
      text_fields.each { |name, value| json.field name.to_s, value if value }
      json.field "fields", @fields if @fields
      json.field "ts", @ts if @ts
      json.field "mrkdwn_in", @mrkdwn_in if @mrkdwn_in
    end
  end

  private def text_fields
    {
      fallback: @fallback, pretext: @pretext,
      author_name: @author_name, author_link: @author_link, author_icon: @author_icon,
      title: @title, title_link: @title_link, text: @text,
      image_url: @image_url, thumb_url: @thumb_url,
      footer: @footer, footer_icon: @footer_icon,
    }
  end

  private def content_issue(issues : Array(ValidationIssue)) : Nil
    return if @content || @fallback.presence || @text.presence

    issues << ValidationIssue.new("attachment.fallback.required", "fallback",
      "An attachment without blocks requires fallback or text.")
  end

  private def dependency_issue(issues : Array(ValidationIssue), value : String?, required : String?,
                               code : String, path : String, message : String) : Nil
    issues << ValidationIssue.new(code, path, message) if value && !required
  end
end
