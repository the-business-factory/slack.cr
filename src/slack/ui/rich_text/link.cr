struct Slack::UI::Checked::RichText::Link
  include NodeValidation

  getter url : String
  getter text : String?
  getter unsafe : Bool?
  getter style : Style?

  def initialize(@url : String, @text : String? = nil, @unsafe : Bool? = nil, @style : Style? = nil)
    validate!
  end

  def type : String
    "link"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @url, "link.url.empty", "url")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "url", @url
      json.field "text", @text if @text
      json.field "unsafe", @unsafe unless @unsafe.nil?
      json.field "style", @style if @style
    end
  end
end
