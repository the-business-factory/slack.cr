# Received style flags. Other flags remain in `raw`.
struct Slack::Interactions::RichText::Style
  getter raw : JSON::Any
  getter bold : Bool?
  getter italic : Bool?
  getter strike : Bool?
  getter code : Bool?
  getter highlight : Bool?
  getter client_highlight : Bool?
  getter underline : Bool?
  getter unlink : Bool?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @bold = Decoder.bool?(object["bold"]?, "#{path}.bold")
    @italic = Decoder.bool?(object["italic"]?, "#{path}.italic")
    @strike = Decoder.bool?(object["strike"]?, "#{path}.strike")
    @code = Decoder.bool?(object["code"]?, "#{path}.code")
    @highlight = Decoder.bool?(object["highlight"]?, "#{path}.highlight")
    @client_highlight = Decoder.bool?(object["client_highlight"]?, "#{path}.client_highlight")
    @underline = Decoder.bool?(object["underline"]?, "#{path}.underline")
    @unlink = Decoder.bool?(object["unlink"]?, "#{path}.unlink")
  end
end
