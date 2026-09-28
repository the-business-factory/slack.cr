# A received click on an icon button.
#
# Slack does not document this action. The fields follow the Bolt JS
# `IconButtonAction` type and are not verified against live Slack, so every
# field after `block_id` is nilable. `raw` keeps the complete action.
struct Slack::Interactions::IconButtonAction
  getter raw : JSON::Any
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  # The icon name, such as `trash`.
  getter icon : String?
  getter value : String?
  getter text : ReceivedText?

  def initialize(@raw : JSON::Any, path : String = "action")
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "icon_button object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "icon_button"
      raise TypeMismatch.new("#{path}.type", "icon_button", actual || "absent or null")
    end
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
    @icon = PayloadAccess.string?(object["icon"]?, "#{path}.icon")
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
    text = object["text"]?
    @text = ReceivedText.new(text, "#{path}.text") if text && !text.raw.nil?
  end

  def type : String
    "icon_button"
  end
end
