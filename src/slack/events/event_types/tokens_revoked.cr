struct Slack::Events::TokensRevoked < Slack::Event
  # Slack sends user IDs, including bot user IDs, never token strings.
  struct Tokens
    include JSON::Serializable

    getter oauth : Array(String) = [] of String
    getter bot : Array(String) = [] of String

    # Returns a JSON snapshot for legacy field lookups. Prefer `oauth` and `bot`.
    # Unknown keys raise `KeyError`.
    def [](key : String) : JSON::Any
      self[key]? || raise KeyError.new("Missing hash key: #{key.inspect}")
    end

    # Returns nil for unknown keys. Omitted or null token kinds return empty arrays.
    def []?(key : String) : JSON::Any?
      case key
      when "oauth" then JSON::Any.new(@oauth.map { |id| JSON::Any.new(id) })
      when "bot"   then JSON::Any.new(@bot.map { |id| JSON::Any.new(id) })
      end
    end
  end

  property tokens : Tokens

  @[JSON::Field(emit_null: false)]
  property event_ts : String?
end
