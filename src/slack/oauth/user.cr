require "json"
require "../mixins/initializer_macros"

struct Slack::Auth::User
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer access_token : String? = nil,
    id : String,
    expires_in : Int32? = nil,
    refresh_token : String? = nil,
    scope : String? = nil,
    token_type : String? = nil

  def inspect(io : IO) : Nil
    io << "Slack::Auth::User([REDACTED])"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end
end
