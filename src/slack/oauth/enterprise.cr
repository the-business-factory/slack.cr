struct Slack::Auth::Enterprise
  include JSON::Serializable
  property id : String, name : String
end
