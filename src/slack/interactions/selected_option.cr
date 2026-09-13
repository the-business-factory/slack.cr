# Received selection data. No outbound lengths, membership, or text-format rules.
struct Slack::Interactions::SelectedOption
  getter raw : JSON::Any
  getter value : String
  getter text : String
  getter text_type : String

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "option object", "null")
    @value = PayloadAccess.string(object["value"]?, "#{path}.value")
    text = PayloadAccess.object?(object["text"]?, "#{path}.text") || raise TypeMismatch.new("#{path}.text", "text object", "absent or null")
    @text = PayloadAccess.string(text["text"]?, "#{path}.text.text")
    @text_type = PayloadAccess.string(text["type"]?, "#{path}.text.type")
  end
end
