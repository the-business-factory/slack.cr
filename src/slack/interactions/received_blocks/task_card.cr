# A received `task_card` block. `status` is the status name, such as
# `in_progress`. `sources` is empty when the block has no sources. Read other
# fields, such as `details`, from `raw`.
# https://docs.slack.dev/reference/block-kit/blocks/task-card-block
struct Slack::Interactions::ReceivedBlocks::TaskCard
  getter raw : JSON::Any
  getter block_id : String?
  getter task_id : String
  getter title : String
  getter status : String
  @sources : Array(Source)

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @task_id = Decoder.string(object, "task_id", path)
    @title = Decoder.string(object, "title", path)
    @status = Decoder.string(object, "status", path)
    @sources = Decoder.sources(object, path)
  end

  def sources : Array(Source)
    @sources.dup
  end
end
