require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatDelete do
  it "sends the channel and message timestamp as JSON" do
    WebMock.stub(:post, "https://slack.com/api/chat.delete")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/json; charset=utf-8"})
      .to_return do |request|
        JSON.parse(request.body || fail("Expected a JSON request body"))
          .should eq JSON.parse(%({"channel":"C03B5PUPDSQ","ts":"1652805073.079609"}))
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/chat-delete-success.json"))
      end

    response = ApiSupport.client.call(Slack::Api::ChatDelete.new(channel: "C03B5PUPDSQ", ts: "1652805073.079609"))

    response.ts.should eq "1652805073.079609"
  end
end
