# The identity of an element in a received block: its type and action ID.
# Read selected values from the action payload or `state.values`. The complete
# element stays in the payload, which `to_json` on the source message or view
# writes back.
struct Slack::Interactions::ReceivedBlocks::ElementSummary
  getter type : String
  # Nil for elements without an action ID, such as images.
  getter action_id : String?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @type = PayloadAccess.string(object["type"]?, "#{path}.type")
    @action_id = PayloadAccess.string?(object["action_id"]?, "#{path}.action_id")
  end
end
