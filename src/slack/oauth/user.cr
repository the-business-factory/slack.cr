struct Slack::Auth::User
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer access_token : String? = nil,
    id : String,
    expires_in : Int32? = nil,
    refresh_token : String? = nil,
    scope : String? = nil,
    token_type : String? = nil
end
