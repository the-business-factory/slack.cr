struct Slack::Interactions::RichText::List
  # Received as sent; the documented values are `bullet` and `ordered`.
  getter style : String
  getter indent : Int32?
  getter offset : Int32?
  getter border : Int32?
  @elements : Array(Section)

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @style = PayloadAccess.string(object["style"]?, "#{path}.style")
    @indent = Decoder.int32?(object["indent"]?, "#{path}.indent")
    @offset = Decoder.int32?(object["offset"]?, "#{path}.offset")
    @border = Decoder.int32?(object["border"]?, "#{path}.border")
    @elements = Decoder.sections(object, path)
  end

  def elements : Array(Section)
    @elements.dup
  end
end
