require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ConversationsHistory do
  it "sends the page selection as form fields and reads messages" do
    WebMock.stub(:post, "https://slack.com/api/conversations.history")
      .with(headers: {"Authorization" => "Bearer xoxb-synthetic",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        URI::Params.parse(request.body.to_s).should eq URI::Params.parse(
          "channel=C03B5PUPDSQ&cursor=bmV4dA%3D%3D&inclusive=true&limit=15" \
          "&oldest=1652800000.000000")
        HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/conversations-history-success.json"))
      end

    request = Slack::Api::ConversationsHistory.new("C03B5PUPDSQ", cursor: "bmV4dA==", inclusive: true,
      oldest: "1652800000.000000", limit: 15)
    response = ApiSupport.client.call(request)

    files = response.messages[2].files.should_not be_nil
    files.first["id"].should eq "F03GL2VDTCG"
  end
end
