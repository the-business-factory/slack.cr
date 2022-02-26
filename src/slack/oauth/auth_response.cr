struct Slack::AuthResponse
  include JSON::Serializable

  property access_token : String,
    app_id : String,
    authed_user : Slack::Auth::User,
    bot_user_id : String,
    enterprise : Slack::Auth::Enterprise,
    ok : Bool,
    scope : String,
    team : Slack::Auth::Team,
    token_type : String?
end
