require "../../../../src/slack"

button = Slack::UI::Checked::BlockElements::Button.new(
  text: Slack::UI::Checked.plain("Approve"),
  action_id: "approve"
)
message = Slack::UI::Checked.message(fallback_text: "Approval required") do |builder|
  builder.section(Slack::UI::Checked.mrkdwn("*Request 42*"))
  builder.actions(elements: [button])
end
request = Slack::Api::CheckedChatPostMessage.new(
  token: "xoxb-synthetic",
  channel: "C123",
  message: message
)
request.to_json
request.result
request.call
