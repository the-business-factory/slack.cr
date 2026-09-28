# Style flags for a rich text `text` element. Slack documents `code` only for text.
struct Slack::UI::Checked::RichText::TextStyle
  getter bold : Bool?
  getter italic : Bool?
  getter strike : Bool?
  getter code : Bool?

  def initialize(@bold : Bool? = nil, @italic : Bool? = nil, @strike : Bool? = nil, @code : Bool? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "bold", @bold unless @bold.nil?
      json.field "italic", @italic unless @italic.nil?
      json.field "strike", @strike unless @strike.nil?
      json.field "code", @code unless @code.nil?
    end
  end
end
