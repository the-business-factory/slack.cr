require "../spec_helper"

describe Slack::Api::ChatDelete do
  describe "#call" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")
      ts = "1652805073.079609"

      WebMock.stub(:post, "https://slack.com/api/chat.delete")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["channel"].as_s.should eq "C03B5PUPDSQ"
          payload["ts"].as_s.should eq ts
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-delete-success.json"))
        end

      response = Slack::Api::ChatDelete
        .new(token: token, channel: "C03B5PUPDSQ", ts: ts)
        .call
        .should be_a(Slack::Models::Chat::Delete)

      response.ts.should eq ts
    end
  end
end
