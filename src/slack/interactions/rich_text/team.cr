struct Slack::Interactions::RichText::Team
  getter team_id : String
  getter style : Style?

  def initialize(raw : JSON::Any, path : String)
    object = Decoder.object(raw, path)
    @team_id = PayloadAccess.string(object["team_id"]?, "#{path}.team_id")
    @style = Decoder.style?(object, path)
  end
end
