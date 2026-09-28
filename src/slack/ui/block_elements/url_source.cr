# A clickable URL reference in a task.
# See https://docs.slack.dev/reference/block-kit/block-elements/url-source-element.
#
# Slack accepts this element only in task cards and streamed task updates.
# Slack does not check that the URL resolves.
struct Slack::UI::BlockElements::UrlSource
  include Slack::UI::ValueValidation

  getter url : String
  getter text : String

  def initialize(@url : String, @text : String)
    validate!
  end

  def type : String
    "url"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("url_source.url.empty", "url", "URL must not be empty.") if @url.empty?
    issues << ValidationIssue.new("url_source.text.empty", "text", "Text must not be empty.") if @text.empty?
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "url", @url
      json.field "text", @text
    end
  end
end
