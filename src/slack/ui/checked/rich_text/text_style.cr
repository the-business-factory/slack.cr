# Style flags for a rich text `text` element. Slack documents `code` only for text.
struct Slack::UI::Checked::RichText::TextStyle
  getter bold : Bool?
  getter italic : Bool?
  getter strike : Bool?
  getter code : Bool?
  getter highlight : Bool?
  getter client_highlight : Bool?
  getter underline : Bool?
  getter unlink : Bool?

  def initialize(@bold : Bool? = nil, @italic : Bool? = nil, @strike : Bool? = nil, @code : Bool? = nil,
                 @highlight : Bool? = nil, @client_highlight : Bool? = nil, @underline : Bool? = nil, @unlink : Bool? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "bold", @bold unless @bold.nil?
      json.field "italic", @italic unless @italic.nil?
      json.field "strike", @strike unless @strike.nil?
      json.field "code", @code unless @code.nil?
      json.field "highlight", @highlight unless @highlight.nil?
      json.field "client_highlight", @client_highlight unless @client_highlight.nil?
      json.field "underline", @underline unless @underline.nil?
      json.field "unlink", @unlink unless @unlink.nil?
    end
  end
end
