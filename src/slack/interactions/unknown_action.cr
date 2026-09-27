struct Slack::Interactions::UnknownAction
  getter type : String?
  getter raw : JSON::Any

  def initialize(@type : String?, @raw : JSON::Any)
  end
end
