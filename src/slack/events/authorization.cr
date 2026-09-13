struct Slack::Events::Authorization
  include JSON::Serializable

  @[JSON::Field(key: "is_bot")]
  getter? bot : Bool

  @[JSON::Field(emit_null: true)]
  getter team_id : String?

  getter user_id : String

  @[JSON::Field(emit_null: true)]
  getter enterprise_id : String?

  @[JSON::Field(key: "is_enterprise_install", emit_null: true)]
  getter enterprise_install : Bool?

  def initialize(
    @user_id : String,
    @bot : Bool,
    @enterprise_id : String? = nil,
    @team_id : String? = nil,
    @enterprise_install : Bool? = nil,
  )
  end

  # Returns a JSON value for legacy lookups by Slack field name.
  # Prefer typed getters. Unknown keys raise `KeyError`.
  def [](key : String) : JSON::Any
    self[key]? || raise KeyError.new("Missing hash key: #{key.inspect}")
  end

  # Returns nil for unknown keys and JSON null for absent optional fields.
  def []?(key : String) : JSON::Any?
    case key
    when "user_id"               then JSON::Any.new(@user_id)
    when "team_id"               then JSON::Any.new(@team_id)
    when "enterprise_id"         then JSON::Any.new(@enterprise_id)
    when "is_bot"                then JSON::Any.new(@bot)
    when "is_enterprise_install" then JSON::Any.new(@enterprise_install)
    end
  end
end
