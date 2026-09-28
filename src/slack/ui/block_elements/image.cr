struct Slack::UI::Checked::BlockElements::Image
  include Slack::UI::Checked::ValueValidation

  getter alt_text : String
  getter image_url : String?
  getter slack_file : Slack::UI::Checked::CompositionObjects::SlackFile?

  def initialize(
    *,
    @alt_text : String,
    @image_url : String,
  )
    @slack_file = nil
    validate!
  end

  def initialize(
    *,
    @alt_text : String,
    @slack_file : Slack::UI::Checked::CompositionObjects::SlackFile,
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
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "alt_text", @alt_text
      json.field "image_url", @image_url if @image_url
      json.field "slack_file", @slack_file if @slack_file
    end
  end
end
