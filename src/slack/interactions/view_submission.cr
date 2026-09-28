# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/
struct Slack::Interactions::ViewSubmission < Slack::Interaction
  # Absent and null decode as empty.
  @[JSON::Field(key: "response_urls")]
  @response_urls : Array(ResponseUrl) = [] of ResponseUrl

  @[JSON::Field(emit_null: false)]
  getter trigger_id : String?

  # Present only for views that a custom function created.
  @[JSON::Field(emit_null: false)]
  getter function_data : FunctionData?

  # Present only for views that a custom function created. It can carry
  # `interactor.secret`, so `inspect` and `to_s` redact it.
  @[JSON::Field(key: "interactivity", emit_null: false)]
  @interactivity_raw : RedactedJSON?

  # The workflow token for a function-created view. `inspect` and `to_s` redact
  # it, and `to_json` omits it.
  @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
  getter bot_access_token : Slack::Auth::Secret?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?

  # The raw interactivity object, including `interactivity_pointer` and `interactor`.
  def interactivity : JSON::Any?
    @interactivity_raw.try(&.value)
  end

  # Returns a copy of the submitted response URLs.
  def response_urls : Array(ResponseUrl)
    @response_urls.dup
  end

  def state_map : StateMap
    @view.try(&.state_map) || StateMap.new(nil, "view.state")
  end

  def plain_text?(block_id : String, action_id : String) : String?
    state_map.plain_text?(block_id, action_id)
  end
end
