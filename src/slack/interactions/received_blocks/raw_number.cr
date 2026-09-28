# A received `raw_number` table cell. Integers stay `Int64`.
struct Slack::Interactions::ReceivedBlocks::RawNumber
  getter raw : JSON::Any
  getter value : Int64 | Float64
  getter text : String?

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @value = Decoder.number(object, "value", path)
    @text = Decoder.string?(object, "text", path)
  end
end
