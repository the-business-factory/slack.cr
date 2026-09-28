# A received `data_visualization` block. The chart stays raw JSON.
# https://docs.slack.dev/reference/block-kit/blocks/data-visualization-block
struct Slack::Interactions::ReceivedBlocks::DataVisualization
  getter raw : JSON::Any
  getter block_id : String?
  getter title : String
  getter chart : JSON::Any

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @title = Decoder.string(object, "title", path)
    @chart = Decoder.raw(object, "chart", path)
  end
end
