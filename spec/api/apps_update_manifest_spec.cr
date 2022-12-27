require "../spec_helper"

describe Slack::Api::AppsManifestUpdate do
  describe "#call" do
    it "should update the Slack app manifest" do
      token = ENV.fetch("SLACK_APP_CONFIG_TOKEN")
      app_id = ENV.fetch("SLACK_APP_ID")

      load_cassette("apps-update-manifest-success") do
        app = JSON.parse File.read("spec/fixtures/app_config/app_manifest.json")
        response = Slack::Api::AppsManifestUpdate
          .new(token: token, app_id: app_id, manifest: app)
          .call
          .should be_a(Slack::Models::Apps::ManifestUpdate)

        response.app_id.should eq app_id
        response.ok?.should be_true
      end
    end
  end
end
