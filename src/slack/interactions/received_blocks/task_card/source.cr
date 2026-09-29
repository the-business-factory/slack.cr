# A received URL source of a `task_card` block. `type` is `url`.
# https://docs.slack.dev/reference/block-kit/blocks/task-card-block
struct Slack::Interactions::ReceivedBlocks::TaskCard::Source
  getter type : String
  getter url : String
  getter text : String

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @type = Decoder.string(object, "type", path)
    @url = Decoder.string(object, "url", path)
    @text = Decoder.string(object, "text", path)
  end
end
