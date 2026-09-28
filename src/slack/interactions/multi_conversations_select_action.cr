struct Slack::Interactions::MultiConversationsSelectAction
  getter raw : JSON::Any
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter selection : MultiConversationsSelectValue

  delegate type, selected_conversations, selected_conversations_presence, to: @selection

  def initialize(@raw : JSON::Any, path : String = "action")
    @selection = MultiConversationsSelectValue.new(@raw, path)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "multi_conversations_select object", "null")
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
  end
end
