# Slack sends the entered address as a string. The library does not check its
# syntax; the application decides what address to accept.
struct Slack::Interactions::EmailInputValue
  getter value : String?
  getter value_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "email_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "email_text_input"
      raise TypeMismatch.new("#{path}.type", "email_text_input", actual || "absent or null")
    end
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
    @value_presence = ValuePresence.of(object["value"]?)
  end

  def type : String
    "email_text_input"
  end
end
