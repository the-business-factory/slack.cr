require "../spec_helper"

describe Slack::Api::ConversationsInfo do
  describe "#call" do
    it "should request the conversation info resource from the API" do
      load_cassette("conversations-info-success") do
        token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN", "faketoken")
        response = Slack::Api::ConversationsInfo
          .new(token: token, channel: "C032TLM43GA")
          .call

        response.is_a?(Slack::Api::Channel).should be_true
        response.name.should eq "links"
      end
    end
  end
end
