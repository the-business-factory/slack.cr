# https://api.slack.com/reference/block-kit/block-elements#button__fields
struct Slack::UI::BlockElements::Button < Slack::UI::BlockElement
  enum Styles
    Primary
    Danger

    def to_s
      case self
      when .primary?
        "primary"
      when .danger?
        "danger"
      else
        raise "Unreachable condition."
      end
    end
  end

  text_object Text, type: "plain_text", max_length: 75

  getter type : String = "button"

  properties_with_initializer \
    action_id : String,
    confirm : Slack::UI::CompositionObjects::Confirmation?,
    style : Styles?,
    text : Text,
    url : String?,
    value : String?

  def to_json(json : JSON::Builder)
    json.object do
      json.field "action_id", action_id
      json.field "confirm", confirm if confirm
      json.field "style", style if style
      json.field "text", text
      json.field "type", type
      json.field "url", url if url
      json.field "value", value if value
    end
  end
end
