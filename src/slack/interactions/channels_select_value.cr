struct Slack::Interactions::ChannelsSelectValue
  getter raw : JSON::Any
  getter selected_channel : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "channels_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "channels_select"
      raise TypeMismatch.new("#{path}.type", "channels_select", actual || "absent or null")
    end
    selection = object["selected_channel"]?
    @selected_channel = PayloadAccess.string?(selection, "#{path}.selected_channel")
  end

  def type : String
    "channels_select"
  end

  def selected_channel_presence : ValuePresence
    ValuePresence.of(@raw["selected_channel"]?)
  end
end
