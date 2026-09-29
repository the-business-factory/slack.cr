struct Slack::Interactions::ChannelsSelectAction
  getter action_id : String
  getter block_id : String
  getter action_ts : String?
  getter selection : ChannelsSelectValue

  delegate type, selected_channel, selected_channel_presence, to: @selection

  def initialize(raw : JSON::Any, path : String = "action")
    @selection = ChannelsSelectValue.new(raw, path)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "channels_select object", "null")
    @action_id = PayloadAccess.string(object["action_id"]?, "#{path}.action_id")
    @block_id = PayloadAccess.string(object["block_id"]?, "#{path}.block_id")
    @action_ts = PayloadAccess.string?(object["action_ts"]?, "#{path}.action_ts")
  end
end
