require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::ApiTest do
  it "calls api.test and returns the echoed arguments" do
    WebMock.stub(:post, "https://slack.com/api/api.test")
      .with(body: "")
      .to_return(body: %({"ok":true,"args":{}}))

    ApiSupport.client.call(Slack::Api::ApiTest.new).args.should be_empty
  end

  it "raises the requested artificial error" do
    WebMock.stub(:post, "https://slack.com/api/api.test")
      .with(body: "error=my_error")
      .to_return(body: %({"ok":false,"error":"my_error","args":{"error":"my_error"}}))

    error = expect_raises(Slack::Api::Error) { ApiSupport.client.call(Slack::Api::ApiTest.new(error: "my_error")) }
    error.code.should eq "my_error"
  end
end
