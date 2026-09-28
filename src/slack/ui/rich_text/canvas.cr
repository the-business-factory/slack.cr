# A link to a canvas, or to one section of it with `section_id`. `text` is the canvas title.
struct Slack::UI::Checked::RichText::Canvas
  include NodeValidation

  getter file_id : String
  getter label : String?
  getter hide_title : Bool?
  getter section_id : String?
  getter text : String?
  getter url : String?
  getter style : Style?

  def initialize(@file_id : String, @label : String? = nil, @hide_title : Bool? = nil, @section_id : String? = nil,
                 @text : String? = nil, @url : String? = nil, @style : Style? = nil)
    validate!
  end

  def type : String
    "canvas"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @file_id, "canvas.file_id.empty", "file_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "file_id", @file_id
      json.field "label", @label if @label
      json.field "hide_title", @hide_title unless @hide_title.nil?
      json.field "section_id", @section_id if @section_id
      json.field "text", @text if @text
      json.field "url", @url if @url
      json.field "style", @style if @style
    end
  end
end
