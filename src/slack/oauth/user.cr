struct Slack::Auth::User
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer access_token : String?,
    id : String,
    expires_in : Int32?,
    refresh_token : String?,
    scope : String?,
    token_type : String?
end
