struct Slack::Interactions::ChannelsSelectValue
  getter selected_channel : String?
  getter selected_channel_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "channels_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "channels_select"
      raise TypeMismatch.new("#{path}.type", "channels_select", actual || "absent or null")
    end
    selection = object["selected_channel"]?
    @selected_channel = PayloadAccess.string?(selection, "#{path}.selected_channel")
    @selected_channel_presence = ValuePresence.of(object["selected_channel"]?)
  end

  def type : String
    "channels_select"
  end
end
