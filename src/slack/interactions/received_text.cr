# A received text object, such as a view title. No outbound length rules apply.
struct Slack::Interactions::ReceivedText
  getter raw : JSON::Any
  getter type : String
  getter text : String
  getter emoji : Bool?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "text object", "null")
    @type = PayloadAccess.string(object["type"]?, "#{path}.type")
    @text = PayloadAccess.string(object["text"]?, "#{path}.text")
    @emoji = PayloadAccess.bool?(object["emoji"]?, "#{path}.emoji")
  end
end
