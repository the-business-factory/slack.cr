struct Slack::Interactions::RichText::Link
  getter raw : JSON::Any
  getter url : String
  getter text : String?
  getter unsafe : Bool?
  # Slack sets these to describe where the link came from and how it is shown.
  getter from_llm : Bool?
  getter is_slack_url : Bool?
  getter truncated : Bool?
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @url = PayloadAccess.string(object["url"]?, "#{path}.url")
    @text = PayloadAccess.string?(object["text"]?, "#{path}.text")
    @unsafe = Decoder.bool?(object["unsafe"]?, "#{path}.unsafe")
    @from_llm = Decoder.bool?(object["from_llm"]?, "#{path}.from_llm")
    @is_slack_url = Decoder.bool?(object["is_slack_url"]?, "#{path}.is_slack_url")
    @truncated = Decoder.bool?(object["truncated"]?, "#{path}.truncated")
    @style = Decoder.style?(object, path)
  end
end
