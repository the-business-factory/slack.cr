# A received click on a positive or negative feedback button.
#
# Slack does not document this action. The fields follow the Bolt JS
# `FeedbackButtonsAction` type and are not verified against live Slack, so
# every field after `block_id` is nilable. `raw` keeps the complete action.
struct Slack::Interactions::FeedbackButtonsAction
  getter raw : JSON::Any
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  # The `value` of the pressed button.
  getter value : String?
  # The label of the pressed button.
  getter text : ReceivedText?

  def initialize(@raw : JSON::Any, path : String = "action")
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "feedback_buttons object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "feedback_buttons"
      raise TypeMismatch.new("#{path}.type", "feedback_buttons", actual || "absent or null")
    end
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
    text = object["text"]?
    @text = ReceivedText.new(text, "#{path}.text") if text && !text.raw.nil?
  end

  def type : String
    "feedback_buttons"
  end
end
