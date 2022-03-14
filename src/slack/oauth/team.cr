struct Slack::Auth::Team
  include JSON::Serializable

  property id : String, name : String
end
