# A link to a file. `text` is the file title.
struct Slack::UI::Checked::RichText::File
  include NodeValidation

  getter file_id : String
  getter text : String?
  getter url : String?
  getter style : Style?

  def initialize(@file_id : String, @text : String? = nil, @url : String? = nil, @style : Style? = nil)
    validate!
  end

  def type : String
    "file"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @file_id, "file.file_id.empty", "file_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "file_id", @file_id
      json.field "text", @text if @text
      json.field "url", @url if @url
      json.field "style", @style if @style
    end
  end
end
