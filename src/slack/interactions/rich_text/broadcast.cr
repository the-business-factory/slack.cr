# Received as sent; the documented ranges are `here`, `channel`, and `everyone`.
struct Slack::Interactions::RichText::Broadcast
  getter range : String
  getter style : Style?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @range = PayloadAccess.string(object["range"]?, "#{path}.range")
    @style = Decoder.style?(object, path)
  end
end
