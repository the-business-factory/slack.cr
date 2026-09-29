struct Slack::Interactions::RichText::Usergroup
  getter usergroup_id : String
  getter style : Style?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @usergroup_id = PayloadAccess.string(object["usergroup_id"]?, "#{path}.usergroup_id")
    @style = Decoder.style?(object, path)
  end
end
