# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/
struct Slack::Interactions::BlockAction < Slack::Interaction
  @[JSON::Field(ignore: true)]
  @state_present : Bool = false

  property actions : JSON::Any?

  # Present when the action happened in a message.
  @[JSON::Field(emit_null: false)]
  getter channel : Channel?

  @[JSON::Field(key: "container", emit_null: false)]
  @container_raw : JSON::Any?

  # The source message. It stays raw JSON; typed received blocks are not decoded yet.
  @[JSON::Field(emit_null: false)]
  getter message : JSON::Any?

  # A short-lived webhook for replies, present when the action happened in a
  # message. Slack deprecates it only for apps created with the Deno Slack SDK.
  @[JSON::Field(emit_null: false)]
  getter response_url : String?

  # The source view version, which `views.update` and `views.publish` accept as `hash`.
  @[JSON::Field(key: "hash", emit_null: false)]
  getter view_hash : String?

  # Present only for blocks that a custom function created.
  @[JSON::Field(emit_null: false)]
  getter function_data : FunctionData?

  # Present only for blocks that a custom function created. It can carry
  # `interactor.secret`, so `inspect` and `to_s` redact it.
  @[JSON::Field(key: "interactivity", emit_null: false)]
  @interactivity_raw : RedactedJSON?

  # The workflow token for a function-created block. `inspect` and `to_s` redact
  # it, and `to_json` omits it.
  @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
  getter bot_access_token : Slack::Auth::Secret?

  @[JSON::Field(emit_null: false, presence: true)]
  property state : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property token : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?

  # The raw interactivity object, including `interactivity_pointer` and `interactor`.
  def interactivity : JSON::Any?
    @interactivity_raw.try(&.value)
  end

  # Decodes the source surface. Raises `TypeMismatch` for a non-object container
  # or a malformed known container.
  def container : Container?
    Container.decode(@container_raw)
  end

  def decoded_actions : Array(Slack::Interactions::Action)
    ActionDecoder.decode(@actions)
  end

  def state_map : StateMap
    # The nilable `state` field collapses explicit JSON null; presence retains it.
    raw = @state
    raw = JSON::Any.new(nil) if raw.nil? && @state_present
    StateMap.new(raw)
  end
end
