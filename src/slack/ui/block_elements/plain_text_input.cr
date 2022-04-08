struct Slack::UI::BlockElements::PlainTextInput < Slack::UI::BlockElement
  alias ActionConfig = CompositionObjects::DispatchActionConfig

  getter type : String = "plain_text_input"

  text_object Placeholder, type: "plain_text", max_length: 150

  properties_with_initializer \
    action_id : String,
    dispatch_action_config : ActionConfig?,
    focus_on_load : Bool = false,
    initial_value : String?,
    max_length : Int16?,
    min_length : Int8?,
    multiline : Bool = false,
    placeholder : Placeholder = Placeholder.new("Placeholder text")

  def after_initialize
    if @action_id.size > 255
      raise Errors::InvalidUIBlock.new("max allowed size for action_id is 255")
    end

    if @min_length.try &.>(3000)
      raise Errors::InvalidUIBlock.new("max allowed size for min_length is 3000")
    end
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "type", type
      json.field "action_id", action_id
      json.field "placeholder", placeholder
      json.field "initial_value", initial_value if initial_value
      json.field "multiline", multiline
      json.field "focus_on_load", focus_on_load
      json.field "min_length", min_length unless min_length.nil?
      json.field "max_length", max_length unless max_length.nil?
      json.field "dispatch_action_config",
        dispatch_action_config if dispatch_action_config
    end
  end
end
