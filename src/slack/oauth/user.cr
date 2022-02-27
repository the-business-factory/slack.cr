struct Slack::Auth::User
  include JSON::Serializable

  property access_token : String?,
    id : String,
    expires_in : Int32?,
    refresh_token : String?,
    scope : String?,
    token_type : String?
end
