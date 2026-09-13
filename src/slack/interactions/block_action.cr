# https://api.slack.com/reference/interaction-payloads/block-actions
struct Slack::Interactions::BlockAction < Slack::Interaction
  @[JSON::Field(ignore: true)]
  @state_present : Bool = false

  property actions : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property channel : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property container : JSON::Any?

  @[JSON::Field(emit_null: false, presence: true)]
  property state : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property token : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?

  def decoded_actions : Array(Slack::Interactions::Action)
    ActionDecoder.decode(@actions)
  end

  def state_map : StateMap
    # The legacy nilable field can collapse explicit JSON null; presence retains it.
    raw = @state
    raw = JSON::Any.new(nil) if raw.nil? && @state_present
    StateMap.new(raw)
  end
end
