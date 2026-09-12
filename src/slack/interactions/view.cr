# Retains arbitrary Slack view content while exposing typed installation ownership.
struct Slack::Interactions::View
  private struct Ownership
    include JSON::Serializable

    getter app_installed_team_id : String?
  end

  getter app_installed_team_id : String?
  # The complete parsed view payload.
  getter payload : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    payload = JSON::Any.new(pull)
    ownership = Ownership.from_json(payload.to_json)
    new(payload, ownership.app_installed_team_id)
  end

  def initialize(@app_installed_team_id : String? = nil)
    values = {} of String => JSON::Any
    if team_id = @app_installed_team_id
      values["app_installed_team_id"] = JSON::Any.new(team_id)
    end
    @payload = JSON::Any.new(values)
  end

  private def initialize(@payload : JSON::Any, @app_installed_team_id : String?)
  end

  def [](key : String) : JSON::Any
    @payload[key]
  end

  def []?(key : String) : JSON::Any?
    @payload[key]?
  end

  def dig(index_or_key : Int | String, *subkeys : Int | String) : JSON::Any
    @payload.dig(index_or_key, *subkeys)
  end

  def dig?(index_or_key : Int | String, *subkeys : Int | String) : JSON::Any?
    @payload.dig?(index_or_key, *subkeys)
  end

  def as_h : Hash(String, JSON::Any)
    @payload.as_h
  end

  def as_h? : Hash(String, JSON::Any)?
    @payload.as_h?
  end

  def to_json(json : JSON::Builder) : Nil
    @payload.to_json(json)
  end
end
