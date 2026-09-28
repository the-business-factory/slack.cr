# The title and optional icon that the message composer shows for an unfurl.
struct Slack::UI::Unfurl::Preview
  include Slack::UI::ValueValidation

  getter title : String
  getter icon_url : String?

  def initialize(*, @title : String, @icon_url : String? = nil)
    validate!
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @title.blank?
      issues << ValidationIssue.new("unfurl.preview.title.blank", "title", "Preview title must not be blank.")
    end
    if @icon_url.try(&.blank?)
      issues << ValidationIssue.new("unfurl.preview.icon_url.blank", "icon_url", "Preview icon URL must not be blank.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "title" do
        json.object do
          json.field "type", "plain_text"
          json.field "text", @title
        end
      end
      json.field "icon_url", @icon_url if @icon_url
    end
  end
end
