# A received button action is not an outbound Button layout value.
struct Slack::Interactions::ButtonAction
  getter action_id : String
  getter block_id : String
  getter value : String?
  getter action_ts : String?
  getter value_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String = "action")
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "button object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "button"
      raise TypeMismatch.new("#{path}.type", "button", actual || "absent or null")
    end
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
    @value_presence = ValuePresence.of(object["value"]?)
  end

  def type : String
    "button"
  end
end
