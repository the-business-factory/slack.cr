struct Slack::Interactions::RichText::Link
  getter raw : JSON::Any
  getter url : String
  getter text : String?
  getter unsafe : Bool?
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @url = PayloadAccess.string(object["url"]?, "#{path}.url")
    @text = PayloadAccess.string?(object["text"]?, "#{path}.text")
    @unsafe = Decoder.bool?(object["unsafe"]?, "#{path}.unsafe")
    @style = Decoder.style?(object, path)
  end
end
