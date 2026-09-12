struct Slack::Interactions::User
  include JSON::Serializable

  getter id : String
  getter team_id : String?
  getter username : String?
  getter name : String?

  def initialize(@id : String, @team_id : String? = nil, @username : String? = nil, @name : String? = nil)
  end
end
