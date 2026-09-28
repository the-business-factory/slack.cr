# Slack sends the entered number as a string. It stays a string, so decimal
# precision and parsing rules remain the application's choice.
struct Slack::Interactions::NumberInputValue
  getter raw : JSON::Any
  getter value : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "number_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "number_input"
      raise TypeMismatch.new("#{path}.type", "number_input", actual || "absent or null")
    end
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
  end

  def type : String
    "number_input"
  end

  def value_presence : ValuePresence
    ValuePresence.of(@raw["value"]?)
  end
end
