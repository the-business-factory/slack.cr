require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ChatMeMessage do
  it "posts a /me message and reads its timestamp" do
    WebMock.stub(:post, "https://slack.com/api/chat.meMessage").to_return do |request|
      JSON.parse(request.body || fail("Expected JSON body"))
        .should eq JSON.parse(%({"channel":"C123ABC456","text":"is deploying build 7"}))
      HTTP::Client::Response.new(200, body: %({"ok":true,"channel":"C123ABC456","ts":"1417671948.000006"}))
    end

    response = ApiSupport.client.call(Slack::Api::ChatMeMessage.new(channel: "C123ABC456", text: "is deploying build 7"))

    response.ts.should eq "1417671948.000006"
    response.channel.should eq "C123ABC456"
  end

  it "rejects empty text before transport" do
    Slack::Api::ChatMeMessage.new(channel: "C1", text: "").validate.map(&.code)
      .should eq ["chat_me_message.text.empty"]
  end
end
