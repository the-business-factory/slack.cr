struct Slack::Interactions::RichText::Date
  getter raw : JSON::Any
  getter timestamp : Int64
  getter format : String
  getter url : String?
  getter fallback : String?
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @timestamp = Decoder.int64(object["timestamp"]?, "#{path}.timestamp")
    @format = PayloadAccess.string(object["format"]?, "#{path}.format")
    @url = PayloadAccess.string?(object["url"]?, "#{path}.url")
    @fallback = PayloadAccess.string?(object["fallback"]?, "#{path}.fallback")
    @style = Decoder.style?(object, path)
  end
end
