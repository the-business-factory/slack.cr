# A received click on a workflow button.
#
# Neither Slack nor the Slack SDKs define this action. The library assumes
# that it echoes the outbound element, so `text` and `workflow` are nilable
# and `workflow` stays raw JSON (`trigger.url` and
# `customizable_input_parameters` when present). `raw` keeps the complete action.
struct Slack::Interactions::WorkflowButtonAction
  getter raw : JSON::Any
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter text : ReceivedText?
  # The raw workflow object, or nil when absent or null.
  getter workflow : JSON::Any?

  def initialize(@raw : JSON::Any, path : String = "action")
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "workflow_button object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "workflow_button"
      raise TypeMismatch.new("#{path}.type", "workflow_button", actual || "absent or null")
    end
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
    text = object["text"]?
    @text = ReceivedText.new(text, "#{path}.text") if text && !text.raw.nil?
    workflow = object["workflow"]?
    @workflow = workflow if PayloadAccess.object?(workflow, "#{path}.workflow")
  end

  def type : String
    "workflow_button"
  end
end
