# Sent when the element has a dispatch_action_config and its Input block sets dispatch_action.
struct Slack::Interactions::NumberInputAction
  getter raw : JSON::Any
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter selection : NumberInputValue

  delegate type, value, value_presence, to: @selection

  def initialize(@raw : JSON::Any, path : String = "action")
    @selection = NumberInputValue.new(@raw, path)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "number_input object", "null")
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
  end
end
