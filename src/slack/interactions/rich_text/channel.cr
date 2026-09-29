struct Slack::Interactions::RichText::Channel
  getter channel_id : String
  getter tab_id : String?
  getter style : Style?
  # Slack sets this when an LLM generated the mention.
  getter from_llm : Bool?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @channel_id = PayloadAccess.string(object["channel_id"]?, "#{path}.channel_id")
    @tab_id = PayloadAccess.string?(object["tab_id"]?, "#{path}.tab_id")
    @from_llm = Decoder.bool?(object["from_llm"]?, "#{path}.from_llm")
    @style = Decoder.style?(object, path)
  end
end
