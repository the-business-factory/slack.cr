struct Slack::Interactions::RichText::User
  getter user_id : String
  getter style : Style?
  # Slack sets this when an LLM generated the mention.
  getter from_llm : Bool?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @user_id = PayloadAccess.string(object["user_id"]?, "#{path}.user_id")
    @from_llm = Decoder.bool?(object["from_llm"]?, "#{path}.from_llm")
    @style = Decoder.style?(object, path)
  end
end
