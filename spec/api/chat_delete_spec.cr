require "../spec_helper"

describe Slack::Api::ChatDelete do
  describe "#call" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      ts = "1652805073.079609"

      load_cassette("chat-delete-success") do
        response = Slack::Api::ChatDelete
          .new(token: token, channel: "C03B5PUPDSQ", ts: ts)
          .call
          .should be_a(Slack::Models::Chat::Delete)

        response.ts.should eq ts
      end
    end
  end
end
