# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/
struct Slack::Interactions::BlockAction < Slack::Interaction
  @[JSON::Field(ignore: true)]
  @state_raw_present : Bool = false

  @[JSON::Field(key: "actions")]
  @actions_raw : JSON::Any?

  @[JSON::Field(ignore: true)]
  @actions : Array(Action)? = nil

  # Present when the action happened in a message.
  @[JSON::Field(emit_null: false)]
  getter channel : Channel?

  @[JSON::Field(key: "container", emit_null: false)]
  @container_raw : JSON::Any?

  # The source message, with typed received blocks.
  @[JSON::Field(emit_null: false)]
  getter message : ReceivedMessage?

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

  @[JSON::Field(key: "state", emit_null: false, presence: true)]
  @state_raw : JSON::Any?

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

  # Decodes the actions once and keeps the result. Returns a copy of the array.
  #
  # A copy of this struct made before the first call does not share the result,
  # because a struct copy has its own fields. That copy decodes again. Bind the
  # payload to a local variable to decode once.
  def actions : Array(Action)
    (@actions ||= ActionDecoder.decode(@actions_raw)).dup
  end

  # The input values in the source view. Read values by block ID and action ID.
  def state : StateMap
    # The nilable `state` field collapses explicit JSON null; presence retains it.
    raw = @state_raw
    raw = JSON::Any.new(nil) if raw.nil? && @state_raw_present
    StateMap.new(raw)
  end
end
