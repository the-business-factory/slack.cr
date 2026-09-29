struct Slack::Interactions::MultiConversationsSelectValue
  @selected_conversations : Array(String)?
  getter selected_conversations_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "multi_conversations_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "multi_conversations_select"
      raise TypeMismatch.new("#{path}.type", "multi_conversations_select", actual || "absent or null")
    end
    selection = object["selected_conversations"]?
    @selected_conversations = if selection && !selection.raw.nil?
                                items = selection.as_a? || raise TypeMismatch.new("#{path}.selected_conversations", "array or null", selection.raw.class.to_s)
                                items.map_with_index { |item, index| PayloadAccess.string(item, "#{path}.selected_conversations[#{index}]") }
                              end
    @selected_conversations_presence = ValuePresence.of(object["selected_conversations"]?)
  end

  def type : String
    "multi_conversations_select"
  end

  def selected_conversations : Array(String)?
    @selected_conversations.try(&.dup)
  end
end
