# Slack documents text and link children; other received inline elements are kept.
struct Slack::Interactions::RichText::Preformatted
  getter raw : JSON::Any
  getter border : Int32?
  getter language : String?
  @elements : Array(Element)

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @border = Decoder.int32?(object["border"]?, "#{path}.border")
    @language = PayloadAccess.string?(object["language"]?, "#{path}.language")
    @elements = Decoder.elements(object, path)
  end

  def elements : Array(Element)
    @elements.dup
  end
end
