struct Slack::Interactions::PlainTextValue
  getter value : String?
  getter value_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "plain_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "plain_text_input"
      raise TypeMismatch.new("#{path}.type", "plain_text_input", actual || "absent or null")
    end
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
    @value_presence = ValuePresence.of(object["value"]?)
  end

  def type : String
    "plain_text_input"
  end
end
