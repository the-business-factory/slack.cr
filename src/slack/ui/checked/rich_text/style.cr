# Optional style flags for rich text mentions, links, dates, and colors.
# Omitted flags and explicit false remain distinct.
struct Slack::UI::Checked::RichText::Style
  getter bold : Bool?
  getter italic : Bool?
  getter strike : Bool?

  def initialize(@bold : Bool? = nil, @italic : Bool? = nil, @strike : Bool? = nil)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "bold", @bold unless @bold.nil?
      json.field "italic", @italic unless @italic.nil?
      json.field "strike", @strike unless @strike.nil?
    end
  end
end
