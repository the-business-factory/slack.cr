struct Slack::Interactions::RichText::Emoji
  getter name : String
  getter unicode : String?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @name = PayloadAccess.string(object["name"]?, "#{path}.name")
    @unicode = PayloadAccess.string?(object["unicode"]?, "#{path}.unicode")
  end
end
