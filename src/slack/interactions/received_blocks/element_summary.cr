# The type and action ID of an element in a received block. Read selected
# values from the action payload or `state.values`, and other fields from `raw`.
struct Slack::Interactions::ReceivedBlocks::ElementSummary
  getter raw : JSON::Any
  getter type : String
  # Nil for elements without an action ID, such as images.
  getter action_id : String?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @type = PayloadAccess.string(object["type"]?, "#{path}.type")
    @action_id = PayloadAccess.string?(object["action_id"]?, "#{path}.action_id")
  end
end
