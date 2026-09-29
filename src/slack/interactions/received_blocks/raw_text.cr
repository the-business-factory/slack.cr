# A received `raw_text` table cell.
struct Slack::Interactions::ReceivedBlocks::RawText
  getter text : String

  def initialize(object : Hash(String, JSON::Any), path : String)
    @text = Decoder.string(object, "text", path)
  end
end
