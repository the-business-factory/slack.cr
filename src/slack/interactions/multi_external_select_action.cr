struct Slack::Interactions::MultiExternalSelectAction
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter selection : MultiExternalSelectValue

  delegate type, selected_options, selected_options_presence, to: @selection

  def initialize(raw : JSON::Any, path : String = "action")
    @selection = MultiExternalSelectValue.new(raw, path)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "multi_external_select object", "null")
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
  end
end
