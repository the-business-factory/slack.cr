require "../spec_helper"
require "../support/api/webmock_client"

module OverflowSnapshotSpec
  alias UI = Slack::UI

  describe "Overflow at the message boundary" do
    it "sends an owned snapshot after callers mutate the options, elements, and builder" do
      options = [UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive")]
      menu = UI::BlockElements::Overflow.new(options: options, action_id: "more")
      elements = [menu]
      actions = UI::Blocks::Actions.new(elements, block_id: "request")
      builder = UI::MessageBuilder.new(fallback_text: "Request actions")
      builder.add(actions)
      client = ApiSupport.client("xoxb-synthetic")
      request = Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", message: builder.build)
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
        HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C-SYNTHETIC","ts":"1710000000.000001","message":{"type":"message","ts":"1710000000.000001"}}))
      end
      client.call(request).channel.should eq "C-SYNTHETIC"
      sent.should eq 1
    end
  end
end
