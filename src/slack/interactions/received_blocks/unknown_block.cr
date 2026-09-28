# Retains a received block or table cell type that this library does not read.
struct Slack::Interactions::ReceivedBlocks::UnknownBlock
  getter type : String
  getter raw : JSON::Any

  def initialize(@type : String, @raw : JSON::Any)
  end
end
