# https://api.slack.com/reference/block-kit/block-elements#button__fields
struct Slack::UI::BlockElements::Button < Slack::UI::BlockElement
  enum Styles
    Primary
    Danger

    def wire_value : String
      case self
      when .primary?
        "primary"
      when .danger?
        "danger"
      else
        raise Slack::Errors::InvalidUIBlock.new("Button style is invalid")
      end
    end

    def to_s : String
      wire_value
    end
  end

  text_object Text, type: "plain_text", max_length: 75

  getter type : String = "button"

  properties_with_initializer \
    action_id : String,
    confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    style : Styles? = nil,
    text : Text,
    url : String? = nil,
    value : String? = nil

  def after_initialize : Nil
    if (style = @style) && !Styles.valid?(style)
      raise Errors::InvalidUIBlock.new("Button style is invalid")
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "action_id", action_id
      json.field "confirm", confirm if confirm
      if style_value = style
        json.field "style", style_value.wire_value
      end
      json.field "text", text
      json.field "type", type
      json.field "url", url if url
      json.field "value", value if value
    end
  end
end
