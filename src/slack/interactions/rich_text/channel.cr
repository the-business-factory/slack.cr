struct Slack::Interactions::RichText::Channel
  getter raw : JSON::Any
  getter channel_id : String
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @channel_id = PayloadAccess.string(object["channel_id"]?, "#{path}.channel_id")
    @style = Decoder.style?(object, path)
  end
end
