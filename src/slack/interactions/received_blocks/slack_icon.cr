# A received Slack icon, such as the `slack_icon` of a `card` block. `name` is
# the icon name, such as `code`.
# https://docs.slack.dev/reference/block-kit/blocks/card-block/
struct Slack::Interactions::ReceivedBlocks::SlackIcon
  getter name : String

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @name = Decoder.string(object, "name", path)
  end
end
