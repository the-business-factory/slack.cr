struct Slack::Interactions::MultiChannelsSelectValue
  @selected_channels : Array(String)?
  getter selected_channels_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "multi_channels_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "multi_channels_select"
      raise TypeMismatch.new("#{path}.type", "multi_channels_select", actual || "absent or null")
    end
    selection = object["selected_channels"]?
    @selected_channels = if selection && !selection.raw.nil?
                           items = selection.as_a? || raise TypeMismatch.new("#{path}.selected_channels", "array or null", selection.raw.class.to_s)
                           items.map_with_index { |item, index| PayloadAccess.string(item, "#{path}.selected_channels[#{index}]") }
                         end
    @selected_channels_presence = ValuePresence.of(object["selected_channels"]?)
  end

  def type : String
    "multi_channels_select"
  end

  def selected_channels : Array(String)?
    @selected_channels.try(&.dup)
  end
end
