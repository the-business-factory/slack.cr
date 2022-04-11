struct Slack::UI::Modal < Slack::UI::Surface
  getter type : String = "modal"

  text_object Title, type: "plain_text", emoji: true, max_length: 100
  text_object Submit, type: "plain_text", emoji: true, max_length: 50
  text_object Close, type: "plain_text", emoji: true, max_length: 50

  properties_with_initializer \
    title : Title,
    submit : Submit,
    close : Close,
    blocks : Array(Slack::TypeAliases::ModalBlock)
end
