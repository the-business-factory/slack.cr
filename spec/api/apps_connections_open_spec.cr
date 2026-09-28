require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::AppsConnectionsOpen do
  it "posts an empty form with the app-level token and reads the WebSocket URL" do
    WebMock.stub(:post, "https://slack.com/api/apps.connections.open")
      .with(headers: {"Authorization" => "Bearer xapp-synthetic",
                      "Content-Type"  => "application/x-www-form-urlencoded"})
      .to_return do |request|
        request.body.to_s.should be_empty
        HTTP::Client::Response.new(200,
          body: %({"ok":true,"url":"wss://wss-primary.slack.com/link/?ticket=12348&app_id=5678"}))
      end

    opened = ApiSupport.client("xapp-synthetic").call(Slack::Api::AppsConnectionsOpen.new)

    opened.url.should eq(URI.parse("wss://wss-primary.slack.com/link/?ticket=12348&app_id=5678"))
  end
end
