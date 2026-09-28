# A received `plan` block. The tasks stay raw JSON.
# https://docs.slack.dev/reference/block-kit/blocks/plan-block
struct Slack::Interactions::ReceivedBlocks::Plan
  getter raw : JSON::Any
  getter block_id : String?
  getter title : String
  # The raw task array.
  getter tasks : JSON::Any

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @title = Decoder.string(object, "title", path)
    @tasks = JSON::Any.new(Decoder.items(object, "tasks", path))
  end
end
