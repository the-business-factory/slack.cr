struct Slack::Interactions::RichText::Canvas
  getter raw : JSON::Any
  getter file_id : String
  getter label : String?
  getter hide_title : Bool?
  getter section_id : String?
  getter text : String?
  getter url : String?
  # Slack sets this when the canvas was inserted as a skill invocation.
  getter is_skill_invocation : Bool?
  getter style : Style?

  def initialize(@raw : JSON::Any, path : String)
    object = Decoder.object(@raw, path)
    @file_id = PayloadAccess.string(object["file_id"]?, "#{path}.file_id")
    @label = PayloadAccess.string?(object["label"]?, "#{path}.label")
    @hide_title = Decoder.bool?(object["hide_title"]?, "#{path}.hide_title")
    @section_id = PayloadAccess.string?(object["section_id"]?, "#{path}.section_id")
    @text = PayloadAccess.string?(object["text"]?, "#{path}.text")
    @url = PayloadAccess.string?(object["url"]?, "#{path}.url")
    @is_skill_invocation = Decoder.bool?(object["is_skill_invocation"]?, "#{path}.is_skill_invocation")
    @style = Decoder.style?(object, path)
  end
end
