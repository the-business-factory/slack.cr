struct Slack::Interactions::ConversationsSelectValue
  getter selected_conversation : String?
  getter selected_conversation_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "conversations_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "conversations_select"
      raise TypeMismatch.new("#{path}.type", "conversations_select", actual || "absent or null")
    end
    selection = object["selected_conversation"]?
    @selected_conversation = PayloadAccess.string?(selection, "#{path}.selected_conversation")
    @selected_conversation_presence = ValuePresence.of(object["selected_conversation"]?)
  end

  def type : String
    "conversations_select"
  end
end
