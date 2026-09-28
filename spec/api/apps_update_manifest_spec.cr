require "../spec_helper"
require "../support/api/webmock_client"

describe Slack::Api::AppsManifestUpdate do
  it "sends the app ID and raw manifest as JSON with the configuration token" do
    manifest = JSON.parse(File.read("spec/fixtures/app_config/app_manifest.json"))
    WebMock.stub(:post, "https://slack.com/api/apps.manifest.update")
      .with(headers: {"Authorization" => "Bearer xoxe.xoxp-synthetic-config",
                      "Content-Type"  => "application/json; charset=utf-8"})
      .to_return do |request|
        payload = JSON.parse(request.body || fail("Expected a JSON request body"))
        payload.as_h.keys.sort!.should eq ["app_id", "manifest"]
        payload["app_id"].as_s.should eq "A012ABCD0A0"
        payload["manifest"].should eq JSON.parse(File.read("spec/fixtures/app_config/app_manifest.json"))
        HTTP::Client::Response.new(200, body: %({"ok":true,"app_id":"A012ABCD0A0","permissions_updated":false}))
      end

    response = ApiSupport.client("xoxe.xoxp-synthetic-config")
      .call(Slack::Api::AppsManifestUpdate.new(app_id: "A012ABCD0A0", manifest: manifest))

    response.app_id.should eq "A012ABCD0A0"
    response.permissions_updated.should be_false
  end
end
