require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::AuthRevoke do
  it "revokes the calling token" do
    sent = [] of String
    WebMock.stub(:post, "https://slack.com/api/auth.revoke")
      .with(headers: {"Authorization" => "Bearer xoxp-synthetic-user"})
      .to_return do |request|
        sent << request.body.to_s
        HTTP::Client::Response.new(200, body: %({"ok":true,"revoked":true}))
      end

    ApiSupport.client("xoxp-synthetic-user").call(Slack::Api::AuthRevoke.new).revoked?.should be_true

    sent.should eq [""]
  end

  it "sends test mode, in which Slack keeps the token" do
    WebMock.stub(:post, "https://slack.com/api/auth.revoke")
      .with(body: "test=true")
      .to_return(body: %({"ok":true,"revoked":false}))

    ApiSupport.client.call(Slack::Api::AuthRevoke.new(test: true)).revoked?.should be_false
  end
end
