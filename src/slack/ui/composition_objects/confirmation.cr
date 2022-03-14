struct Slack::UI::CompositionObjects::Confirmation
  include Slack::UI::DynamicTextComposition

  text_object Title, type: "plain_text", max_length: 100
  text_object Text, max_length: 300
  text_object Confirm, type: "plain_text", max_length: 30
  text_object Deny, type: "plain_text", max_length: 30

  properties_with_initializer \
    confirm : Confirm,
    deny : Deny,
    style : String?,
    text : Text,
    title : Title
end
