require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::ReactionsAdd do
  describe "#call" do
    it "should request the reactions add resource from the API" do
      WebMock.stub(:post, "https://slack.com/api/reactions.add")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["channel"].as_s.should eq "C03B5PUPDSQ"
          payload["timestamp"].as_s.should eq "1652892820.098929"
          payload["name"].as_s.should eq "t-rex"
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/reactions-add-success.json"))
        end

      channel = "C03B5PUPDSQ"
      ts = "1652892820.098929"
      reaction = "t-rex"
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      response = Slack::Api::ReactionsAdd
        .new(token: token, name: reaction, channel: channel, timestamp: ts,
          transport: AuthSupport::WebMockTransport.new)
        .call
        .should be_a(Slack::Models::DefaultResponse)
      response.ok?.should be_true
    end
  end
end
