# Received menu selection. Retains unmodeled fields without outbound validation.
struct Slack::Interactions::OverflowAction
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter selected_option : SelectedOption

  def initialize(raw : JSON::Any, path : String = "action")
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "overflow object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "overflow"
      raise TypeMismatch.new("#{path}.type", "overflow", actual || "absent or null")
    end
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
    selection = object["selected_option"]? || raise TypeMismatch.new("#{path}.selected_option", "option object", "absent")
    @selected_option = SelectedOption.new(selection, "#{path}.selected_option")
  end

  def type : String
    "overflow"
  end
end
