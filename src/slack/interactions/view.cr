# Retains arbitrary Slack view content while exposing typed installation ownership.
# Other typed getters read the retained payload when called. They return nil for
# an absent or null field and raise `TypeMismatch` for a malformed one.
struct Slack::Interactions::View
  private struct Ownership
    include JSON::Serializable

    getter app_installed_team_id : String?
  end

  getter app_installed_team_id : String?
  # The complete parsed view payload. `to_json` writes it back.
  @payload : JSON::Any

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

  def id : String?
    string?("id")
  end

  def team_id : String?
    string?("team_id")
  end

  # The view type, such as `modal` or `home`.
  def type : String?
    string?("type")
  end

  def title : ReceivedText?
    raw = @payload["title"]?
    ReceivedText.new(raw, "view.title") if raw && !raw.raw.nil?
  end

  def callback_id : String?
    string?("callback_id")
  end

  def private_metadata : String?
    string?("private_metadata")
  end

  def external_id : String?
    string?("external_id")
  end

  # The view version, which `views.update` and `views.publish` accept as `hash`.
  def view_hash : String?
    string?("hash")
  end

  def root_view_id : String?
    string?("root_view_id")
  end

  def previous_view_id : String?
    string?("previous_view_id")
  end

  def app_id : String?
    string?("app_id")
  end

  def bot_id : String?
    string?("bot_id")
  end

  def clear_on_close : Bool?
    PayloadAccess.bool?(@payload["clear_on_close"]?, "view.clear_on_close")
  end

  def notify_on_close : Bool?
    PayloadAccess.bool?(@payload["notify_on_close"]?, "view.notify_on_close")
  end

  @decoded_blocks : Array(ReceivedBlock)? = nil

  # Decodes the view blocks. Returns an empty array when the view has none.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(ReceivedBlock)
    @decoded_blocks ||= ReceivedBlocks.decode(@payload["blocks"]?, "view.blocks")
  end

  def state : StateMap
    StateMap.new(@payload["state"]?, "view.state")
  end

  def plain_text?(block_id : String, action_id : String) : String?
    state.plain_text?(block_id, action_id)
  end

  private def string?(key : String) : String?
    PayloadAccess.string?(@payload[key]?, "view.#{key}")
  end
end
