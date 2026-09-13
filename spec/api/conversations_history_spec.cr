require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::ConversationsHistory do
  describe "#call" do
    it "should post a chat message with one block" do
      token = ENV.fetch("SLACK_TEAM_AUTH_TOKEN")

      WebMock.stub(:get, "https://slack.com/api/conversations.history?channel=C03B5PUPDSQ&include_all_metadata=false&inclusive=false")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_TEAM_AUTH_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["channel"].as_s.should eq "C03B5PUPDSQ"
          payload["inclusive"].as_bool.should be_false
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/conversations-history-success.json"))
        end

      response = Slack::Api::ConversationsHistory
        .new(token: token, channel: "C03B5PUPDSQ", transport: AuthSupport::WebMockTransport.new)
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
