struct Slack::Interactions::RichText::File
  getter file_id : String
  getter text : String?
  getter url : String?
  # Slack sets this when the file was inserted as a skill invocation.
  getter is_skill_invocation : Bool?
  getter style : Style?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @file_id = PayloadAccess.string(object["file_id"]?, "#{path}.file_id")
    @text = PayloadAccess.string?(object["text"]?, "#{path}.text")
    @url = PayloadAccess.string?(object["url"]?, "#{path}.url")
    @is_skill_invocation = Decoder.bool?(object["is_skill_invocation"]?, "#{path}.is_skill_invocation")
    @style = Decoder.style?(object, path)
  end
end
