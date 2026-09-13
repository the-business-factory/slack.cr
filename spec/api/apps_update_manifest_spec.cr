require "../spec_helper"
require "../support/auth/webmock_transport"

describe Slack::Api::AppsManifestUpdate do
  describe "#call" do
    it "should update the Slack app manifest" do
      token = ENV.fetch("SLACK_APP_CONFIG_TOKEN")
      app_id = ENV.fetch("SLACK_APP_ID")

      WebMock.stub(:post, "https://slack.com/api/apps.manifest.update")
        .with(headers: {"Authorization" => "Bearer #{ENV.fetch("SLACK_APP_CONFIG_TOKEN")}"})
        .to_return do |request|
          payload = JSON.parse(request.body || fail("Expected a JSON request body"))
          payload["app_id"].as_s.should eq app_id
          payload["manifest"].should eq JSON.parse(File.read("spec/fixtures/app_config/app_manifest.json"))
          HTTP::Client::Response.new(200, body: File.read("spec/fixtures/api/apps-update-manifest-success.json"))
        end

      app = JSON.parse File.read("spec/fixtures/app_config/app_manifest.json")
      response = Slack::Api::AppsManifestUpdate
        .new(token: token, app_id: app_id, manifest: app, transport: AuthSupport::WebMockTransport.new)
        .call
        .should be_a(Slack::Models::Apps::ManifestUpdate)

      response.app_id.should eq app_id
      response.ok?.should be_true
    end
  end
end
