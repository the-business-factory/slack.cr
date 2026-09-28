# Up to 50 message blocks inside the streamed message.
#
# The chunk validates its blocks with the message rules and keeps its own copy.
struct Slack::Api::Streaming::BlocksChunk
  @blocks : Slack::UI::Message

  def initialize(blocks : Enumerable(T)) forall T
    @blocks = Slack::UI::Message.with_slack_generated_fallback(blocks)
  end

  def blocks : Array(Slack::UI::MessageBlock)
    @blocks.blocks
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", "blocks"
      json.field "blocks" do
        @blocks.blocks_to_json(json)
      end
    end
  end
end
