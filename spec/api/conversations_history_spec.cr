require "../spec_helper"

describe Slack::Api::ConversationsHistory do
  describe "#call" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")

      load_cassette("conversations-history-success") do
        response = Slack::Api::ConversationsHistory
          .new(token: token, channel: "C03B5PUPDSQ")
          .call
          .should be_a(Slack::Models::ConversationsHistory)

        files = response
          .messages[2]
          .files
          .should be_a(Array(Hash(String, JSON::Any)))

        files.first["id"].should eq "F03GL2VDTCG"
      end
    end
  end
end
