struct Slack::Events::TokensRevoked < Slack::Event
  # Slack sends user IDs, including bot user IDs, never token strings.
  struct Tokens
    include JSON::Serializable

    getter oauth : Array(String) = [] of String
    getter bot : Array(String) = [] of String
  end

  property tokens : Tokens

  @[JSON::Field(emit_null: false)]
  property event_ts : String?
end
