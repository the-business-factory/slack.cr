require "../../../support/block_kit/prototype"

legacy = Slack::UI::Components::TextSection.render("*Legacy*", markdown: true)
checked = Slack::UI::Checked::LegacyAdapter.section(legacy)
message = Slack::UI::Checked::Proof::Message.new(
  fallback_text: "Legacy content",
  blocks: [checked]
)
request = Slack::UI::Checked::Proof::CheckedChatPostMessage.new(
  token: "xoxb-synthetic",
  channel: "C123",
  message: message
)
request.to_json
request.result
request.call
