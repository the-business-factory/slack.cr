require "../spec_helper"

describe Slack::Api::ReactionsAdd do
  describe "#call" do
    it "should request the reactions add resource from the API" do
      load_cassette("reactions-add-success") do
        channel = "C03B5PUPDSQ"
        ts = "1652892820.098929"
        reaction = "t-rex"
        token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
        response = Slack::Api::ReactionsAdd
          .new(token: token, name: reaction, channel: channel, timestamp: ts)
          .call
          .should be_a(Slack::Models::DefaultResponse)
        response.ok.should be_true
      end
    end
  end
end
