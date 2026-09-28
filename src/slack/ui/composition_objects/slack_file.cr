# Exactly one Slack file locator. File access and media type are checked by Slack.
struct Slack::UI::CompositionObjects::SlackFile
  include Slack::UI::ValueValidation

  getter id : String?
  getter url : String?

  def initialize(*, @id : String)
    @url = nil
    validate!
  end

  def initialize(*, @url : String)
    @id = nil
    validate!
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @id.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new("slack_file.id.empty", "id", "File ID must not be empty.")
    end
    if @url.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new("slack_file.url.empty", "url", "File URL must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "id", @id if @id
      json.field "url", @url if @url
    end
  end
end
