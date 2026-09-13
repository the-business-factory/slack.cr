require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::ChatPostMessage do
  describe ".post_blocks" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      channel_id = ENV.fetch("SLACK_BOT_POSTING_CHANNEL")

      WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["channel"].as_s.should eq channel_id
          payload["blocks"].as_a.size.should eq 1
          payload["blocks"][0]["text"]["text"].as_s.should eq "*Testing!*"
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-section.json"))
        end

      section = Slack::UI::Components::TextSection
        .render(text: "*Testing!*", markdown: true)

      response = Slack::Api::ChatPostMessage
        .post_blocks(token: token, channel: channel_id, blocks: [section],
          transport: AuthSupport::WebMockTransport.new)
        .should be_a(Slack::Models::Chat::PostMessage)

      response.ok?.should be_true
      response.channel.should eq channel_id
      response.message["bot_id"].should eq "B03ATRRPV4K"
    end

    it "should post a chat message with multiple blocks" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      channel_id = ENV.fetch("SLACK_BOT_POSTING_CHANNEL")

      WebMock.stub(:post, "https://slack.com/api/chat.postMessage")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["channel"].as_s.should eq channel_id
          payload["blocks"].as_a.size.should eq 2
          payload["blocks"][0]["text"]["text"].as_s.should eq "*Testing!*"
          payload["blocks"][1]["type"].as_s.should eq "actions"
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-post-success-section-with-button-actions.json"))
        end

      section = Slack::UI::Components::TextSection
        .render(text: "*Testing!*", markdown: true)

      actions = Slack::UI::Components::ButtonActions
        .render(action_id: "button_action_id")

      response = Slack::Api::ChatPostMessage
        .post_blocks(token: token, channel: channel_id, blocks: [section, actions],
          transport: AuthSupport::WebMockTransport.new)
        .should be_a(Slack::Models::Chat::PostMessage)

      response.ok?.should be_true
      response.channel.should eq channel_id
      response.message["bot_id"].should eq "B03ATRRPV4K"
    end
  end
end
