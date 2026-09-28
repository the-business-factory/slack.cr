require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ReactionsAdd do
  it "sends the reaction name, channel, and message timestamp as JSON" do
    WebMock.stub(:post, "https://slack.com/api/reactions.add")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/json; charset=utf-8"})
      .to_return do |request|
        JSON.parse(request.body || fail("Expected a JSON request body"))
          .should eq JSON.parse(%({"channel":"C03B5PUPDSQ","name":"t-rex","timestamp":"1652892820.098929"}))
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/reactions-add-success.json"))
      end

    request = Slack::Api::ReactionsAdd.new(channel: "C03B5PUPDSQ", name: "t-rex", timestamp: "1652892820.098929")
    ApiSupport.client.call(request).ok?.should be_true
  end
end
