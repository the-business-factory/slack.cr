struct Slack::Interactions::PlainTextValue
  getter raw : JSON::Any
  getter value : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "plain_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "plain_text_input"
      raise TypeMismatch.new("#{path}.type", "plain_text_input", actual || "absent or null")
    end
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
  end

  def type : String
    "plain_text_input"
  end

  def value_presence : ValuePresence
    ValuePresence.of(@raw["value"]?)
  end
end
