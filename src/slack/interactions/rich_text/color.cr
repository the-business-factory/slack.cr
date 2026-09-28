struct Slack::Interactions::RichText::Color
  getter raw : JSON::Any
  getter value : String
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @value = PayloadAccess.string(object["value"]?, "#{path}.value")
    @style = Decoder.style?(object, path)
  end
end
