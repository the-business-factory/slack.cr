# https://api.slack.com/reference/block-kit/blocks#input
struct Slack::UI::Blocks::Input < Slack::UI::Block
  getter type : String = "input"

  text_object Label, type: "plain_text", max_length: 2000

  properties_with_initializer \
    element : BlockElements::PlainTextInput,
    label : Label,
    dispatch_action : Bool = false
end
