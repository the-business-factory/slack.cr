require "../../src/slack"
require "webmock"
require "./webmock_transport"

module OfflineMessageUpdateExample
  alias UI = Slack::UI::Checked

  def self.run(output : IO = STDOUT) : Nil
    WebMock.allow_net_connect = false
    transport = OfflineExample::WebMockTransport.new
    token = "xoxb-synthetic-message-update"
    WebMock.stub(:post, "https://slack.com/api/chat.postMessage").to_return do |request|
      body = JSON.parse(request.body || raise "Missing posted message")
      raise "Missing approval control" unless body["blocks"][1]["elements"][0]["action_id"] == "request.approve"
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1710000000.000001","message":{"text":"Request 42 needs approval."}}))
    end
    pending = UI.message(fallback_text: "Request 42 needs approval.") do |builder|
      builder.section(UI.plain("Request 42 needs approval."), block_id: "request.pending")
      builder.actions(block_id: "request.controls", elements: [UI::BlockElements::Button.new(
        text: UI.plain("Approve"), action_id: "request.approve", value: "42")])
    end
    posted = Slack::Api::CheckedChatPostMessage.new(
      token: token, channel: "C123", message: pending, transport: transport).call

    # Simulate application approval. Use fresh block IDs for the new version.
    approved = UI.message(fallback_text: "Request 42 approved.") do |builder|
      builder.section(UI.mrkdwn("*Request 42 approved.*"), block_id: "request.approved")
    end
    WebMock.stub(:post, "https://slack.com/api/chat.update").to_return do |request|
      expected = JSON.parse(<<-JSON)
        {"channel":"C123","ts":"1710000000.000001","text":"Request 42 approved.","blocks":[{"type":"section","block_id":"request.approved","text":{"type":"mrkdwn","text":"*Request 42 approved.*"}}],"as_user":true}
        JSON
      raise "Incorrect replacement" unless JSON.parse(request.body || raise "Missing update") == expected
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123","ts":"1710000000.000001","text":"Request 42 approved."}))
    end
    channel = posted.channel || raise "Missing posted channel"
    updated = Slack::Api::CheckedChatUpdate.new(
      token: token, channel: channel, ts: posted.ts, message: approved,
      as_user: true, transport: transport).call
    output.puts "Updated #{updated.channel}/#{updated.ts}: #{updated.text}"
  end
end
