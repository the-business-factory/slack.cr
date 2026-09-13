struct Slack::UI::Checked::Blocks::Image
  include Slack::UI::Checked::ValueValidation

  getter alt_text : String
  getter image_url : String?
  getter slack_file : Slack::UI::Checked::CompositionObjects::SlackFile?
  getter title : Slack::UI::Checked::CompositionObjects::PlainText?
  getter block_id : String?

  def initialize(
    *,
    @alt_text : String,
    @image_url : String,
    @title : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @block_id : String? = nil,
  )
    @slack_file = nil
    validate!
  end

  def initialize(
    *,
    @alt_text : String,
    @slack_file : Slack::UI::Checked::CompositionObjects::SlackFile,
    @title : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @block_id : String? = nil,
  )
    @image_url = nil
    validate!
  end

  def type : String
    "image"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @alt_text.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("image.alt_text.empty", "alt_text", "Provide a plain-text summary of the image.")
    end
    if @image_url.try(&.empty?)
      issues << Slack::UI::Checked::ValidationIssue.new("image.image_url.empty", "image_url", "Image URL must not be empty.")
    end
    length_issue(issues, @image_url, 3000, "image.image_url.too_long", "image_url")
    if file = @slack_file
      file.validate.each { |issue| issues << issue.at("slack_file") }
    end
    length_issue(issues, @alt_text, 2000, "image.alt_text.too_long", "alt_text")
    length_issue(issues, @block_id, 255, "image.block_id.too_long", "block_id")
    if title = @title
      title.validate.each { |issue| issues << issue.at("title") }
      length_issue(issues, title.text, 2000, "image.title.too_long", "title.text")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "alt_text", @alt_text
      json.field "image_url", @image_url if @image_url
      json.field "slack_file", @slack_file if @slack_file
      json.field "title", @title if @title
      json.field "block_id", @block_id if @block_id
    end
  end
end
