# Received style flags. Other flags, such as `underline`, remain in `raw`.
struct Slack::Interactions::RichText::Style
  getter raw : JSON::Any
  getter bold : Bool?
  getter italic : Bool?
  getter strike : Bool?
  getter code : Bool?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @bold = Decoder.bool?(object["bold"]?, "#{path}.bold")
    @italic = Decoder.bool?(object["italic"]?, "#{path}.italic")
    @strike = Decoder.bool?(object["strike"]?, "#{path}.strike")
    @code = Decoder.bool?(object["code"]?, "#{path}.code")
  end
end
