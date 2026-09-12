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
end
