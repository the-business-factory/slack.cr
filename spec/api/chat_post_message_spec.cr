require "../spec_helper"

describe Slack::Api::ChatPostMessage do
  describe ".post_blocks" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      channel_id = ENV.fetch("SLACK_BOT_POSTING_CHANNEL")

      load_cassette("chat-post-success-section") do
        section = Slack::UI::Components::TextSection
          .render(text: "*Testing!*", markdown: true)

        response = Slack::Api::ChatPostMessage
          .post_blocks(token: token, channel: channel_id, blocks: [section])
          .should be_a(Slack::Models::Chat::PostMessage)

        response.ok?.should be_true
        response.channel.should eq channel_id
        response.message["bot_id"].should eq "B03ATRRPV4K"
      end
    end

    it "should post a chat message with multiple blocks" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      channel_id = ENV.fetch("SLACK_BOT_POSTING_CHANNEL")

      load_cassette("chat-post-success-section-with-button-actions") do
        section = Slack::UI::Components::TextSection
          .render(text: "*Testing!*", markdown: true)

        actions = Slack::UI::Components::ButtonActions
          .render(action_id: "button_action_id")

        response = Slack::Api::ChatPostMessage
          .post_blocks(token: token, channel: channel_id, blocks: [section, actions])
          .should be_a(Slack::Models::Chat::PostMessage)

        response.ok?.should be_true
        response.channel.should eq channel_id
        response.message["bot_id"].should eq "B03ATRRPV4K"
      end
    end
  end
end
