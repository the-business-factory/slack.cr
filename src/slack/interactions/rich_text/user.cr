struct Slack::Interactions::RichText::User
  getter raw : JSON::Any
  getter user_id : String
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @user_id = PayloadAccess.string(object["user_id"]?, "#{path}.user_id")
    @style = Decoder.style?(object, path)
  end
end
