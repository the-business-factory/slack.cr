struct Slack::Interactions::RichText::Quote
  getter raw : JSON::Any
  getter border : Int32?
  @elements : Array(Element)

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @border = Decoder.int32?(object["border"]?, "#{path}.border")
    @elements = Decoder.elements(object, path)
  end

  def elements : Array(Element)
    @elements.dup
  end
end
