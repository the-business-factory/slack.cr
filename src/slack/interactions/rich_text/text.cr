struct Slack::Interactions::RichText::Text
  getter raw : JSON::Any
  getter text : String
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @text = PayloadAccess.string(object["text"]?, "#{path}.text")
    @style = Decoder.style?(object, path)
  end
end
