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

  it "deletes as the user when as_user is true" do
    request = Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000100", as_user: true)

    JSON.parse(request.to_json).should eq JSON.parse(%({"channel":"C1","ts":"1710000000.000100","as_user":true}))
  end

  it "raises message_not_found as the error code" do
    WebMock.stub(:post, "https://slack.com/api/chat.delete")
      .to_return(body: %({"ok":false,"error":"message_not_found"}))

    expect_raises(Slack::Api::Error) do
      ApiSupport.client.call(Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000100"))
    end.code.should eq "message_not_found"
  end
end
