require "../spec_helper"
require "../support/auth/webmock_transport"

module OverflowSnapshotSpec
  alias UI = Slack::UI::Checked

  describe "Overflow at the checked message boundary" do
    it "sends an owned snapshot after callers mutate the options, elements, and builder" do
      options = [UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive")]
      menu = UI::BlockElements::Overflow.new(options: options, action_id: "more")
      elements = [menu]
      actions = UI::Blocks::Actions.new(elements, block_id: "request")
      builder = UI::MessageBuilder.new(fallback_text: "Request actions")
      builder.add(actions)
      request = Slack::Api::CheckedChatPostMessage.new(token: "xoxb-synthetic", channel: "C-SYNTHETIC", message: builder.build, transport: AuthSupport::WebMockTransport.new)
      options.clear
      menu.options.clear
      elements.clear
      actions.elements.clear
      builder.divider
      expected = JSON.parse(File.read("spec/fixtures/block_kit/overflow_chat_postMessage.json"))
      JSON.parse(request.to_json).should eq expected
      sent = 0
      WebMock.stub(:post, "https://slack.com/api/chat.postMessage").with(headers: {"Authorization" => "Bearer xoxb-synthetic"}).to_return do |http_request|
        sent += 1
        JSON.parse(http_request.body || fail("Missing body")).should eq expected
        HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{}}))
      end
      request.result.status_code.should eq 200
      request.call.channel.should eq "C-SYNTHETIC"
      sent.should eq 1
    end
  end
end
