require "../../../../src/slack"
require "../../../support/auth/webmock_transport"

view = Slack::UI::Checked.home do |builder|
  builder.header(text: Slack::UI::Checked.plain("Projects"))
end
request = Slack::Api::CheckedViewsPublish.new(token: "xoxb-synthetic", user_id: "U123", view: view, hash: "opaque-hash", interactivity_pointer: "synthetic-pointer", transport: AuthSupport::WebMockTransport.new)
request.to_json
# Compiles both sending entrypoints without executing them in this fixture.
if ARGV.includes?("--send")
  request.result
  request.call
end
