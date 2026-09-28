# Slack checks the URL format in the client. The value is not checked again here.
struct Slack::Interactions::UrlInputValue
  getter raw : JSON::Any
  getter value : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "url_text_input object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "url_text_input"
      raise TypeMismatch.new("#{path}.type", "url_text_input", actual || "absent or null")
    end
    @value = PayloadAccess.string?(object["value"]?, "#{path}.value")
  end

  def type : String
    "url_text_input"
  end

  def value_presence : ValuePresence
    ValuePresence.of(@raw["value"]?)
  end
end
