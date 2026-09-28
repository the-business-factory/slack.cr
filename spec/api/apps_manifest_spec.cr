require "../spec_helper"
require "../support/api/webmock_client"

private CONFIG_TOKEN = "xoxe.xoxp-synthetic-config"

private def manifest_fixture : JSON::Any
  JSON.parse(File.read("spec/fixtures/app_config/app_manifest.json"))
end

# Stubs *method* for the configuration token and returns the form fields of each request.
private def stub_manifest_method(method : String, response : String) : Array(URI::Params)
  sent = [] of URI::Params
  WebMock.stub(:post, "https://slack.com/api/#{method}")
    .with(headers: {"Authorization" => "Bearer #{CONFIG_TOKEN}",
                    "Content-Type"  => "application/x-www-form-urlencoded"})
    .to_return do |request|
      sent << URI::Params.parse(request.body.to_s)
      HTTP::Client::Response.new(200, body: response)
    end
  sent
end

private def config_client : Slack::Api::Client
  ApiSupport.client(CONFIG_TOKEN)
end

describe Slack::Api::AppsManifestCreate do
  it "sends the manifest as JSON text and returns the new app's credentials" do
    sent = stub_manifest_method("apps.manifest.create", <<-JSON)
      {"ok":true,"app_id":"A012ABCD0A0",
       "credentials":{"client_id":"1234.5678","client_secret":"synthetic-client-secret",
        "verification_token":"synthetic-verification","signing_secret":"synthetic-signing-secret"},
       "oauth_authorize_url":"https://slack.com/oauth/v2/authorize?client_id=1234.5678&scope=commands"}
      JSON

    created = config_client.call(Slack::Api::AppsManifestCreate.new(manifest_fixture, team_id: "T123"))

    sent.size.should eq 1
    sent[0].to_h.keys.sort!.should eq ["manifest", "team_id"]
    JSON.parse(sent[0]["manifest"]).should eq manifest_fixture
    sent[0]["team_id"].should eq "T123"
    created.app_id.should eq "A012ABCD0A0"
    created.oauth_authorize_url.should eq URI.parse(
      "https://slack.com/oauth/v2/authorize?client_id=1234.5678&scope=commands")
    credentials = created.credentials
    credentials.client_id.should eq "1234.5678"
    credentials.client_secret.value.should eq "synthetic-client-secret"
    credentials.verification_token.value.should eq "synthetic-verification"
    credentials.signing_secret.value.should eq "synthetic-signing-secret"
  end

  it "keeps the returned secrets out of inspect output" do
    stub_manifest_method("apps.manifest.create", <<-JSON)
      {"ok":true,"app_id":"A1",
       "credentials":{"client_id":"1.2","client_secret":"canary-client-secret",
        "verification_token":"canary-verification","signing_secret":"canary-signing-secret"},
       "oauth_authorize_url":"https://slack.com/oauth/v2/authorize?client_id=1.2"}
      JSON

    created = config_client.call(Slack::Api::AppsManifestCreate.new(manifest_fixture))

    created.inspect.should_not contain("canary")
    created.credentials.inspect.should_not contain("canary")
  end

  it "gives each manifest problem from an invalid_manifest failure" do
    stub_manifest_method("apps.manifest.create", <<-JSON)
      {"ok":false,"error":"invalid_manifest","errors":[
       {"message":"Event Subscription requires either Request URL or Socket Mode Enabled",
        "pointer":"/settings/event_subscriptions"}]}
      JSON

    error = expect_raises(Slack::Api::Error, "invalid_manifest") do
      config_client.call(Slack::Api::AppsManifestCreate.new(manifest_fixture))
    end

    error.details.map { |detail| {detail.pointer, detail.message} }.should eq [
      {"/settings/event_subscriptions", "Event Subscription requires either Request URL or Socket Mode Enabled"},
    ]
    error.message.to_s.should_not contain("Event Subscription")
  end
end

describe Slack::Api::AppsManifestValidate do
  it "sends the manifest and optional app ID and accepts a valid manifest" do
    sent = stub_manifest_method("apps.manifest.validate", %({"ok":true,"errors":[]}))

    config_client.call(Slack::Api::AppsManifestValidate.new(manifest_fixture, app_id: "A012ABCD0A0"))
      .ok?.should be_true

    sent.size.should eq 1
    sent[0].to_h.keys.sort!.should eq ["app_id", "manifest"]
    sent[0]["app_id"].should eq "A012ABCD0A0"
    JSON.parse(sent[0]["manifest"]).should eq manifest_fixture
  end

  it "gives every manifest problem in order" do
    stub_manifest_method("apps.manifest.validate", <<-JSON)
      {"ok":false,"error":"invalid_manifest","errors":[
       {"message":"Event Subscription requires either Request URL or Socket Mode Enabled",
        "pointer":"/settings/event_subscriptions"},
       {"message":"Interactivity requires a Request URL","pointer":"/settings/interactivity"}]}
      JSON

    error = expect_raises(Slack::Api::Error) do
      config_client.call(Slack::Api::AppsManifestValidate.new(manifest_fixture))
    end

    error.code.should eq "invalid_manifest"
    error.details.map(&.pointer).should eq ["/settings/event_subscriptions", "/settings/interactivity"]
    error.details.map(&.message).should eq [
      "Event Subscription requires either Request URL or Socket Mode Enabled",
      "Interactivity requires a Request URL",
    ]
  end
end

describe Slack::Api::AppsManifestUpdate do
  it "sends the app ID and manifest with the configuration token" do
    sent = stub_manifest_method("apps.manifest.update",
      %({"ok":true,"app_id":"A012ABCD0A0","permissions_updated":true}))

    updated = config_client.call(Slack::Api::AppsManifestUpdate.new(app_id: "A012ABCD0A0", manifest: manifest_fixture))

    sent[0].to_h.keys.sort!.should eq ["app_id", "manifest"]
    sent[0]["app_id"].should eq "A012ABCD0A0"
    JSON.parse(sent[0]["manifest"]).should eq manifest_fixture
    updated.app_id.should eq "A012ABCD0A0"
    updated.permissions_updated.should be_true
  end

  it "keeps its manifest when the caller changes the given or returned manifest" do
    manifest = JSON.parse(%({"display_information":{"name":"original"}}))
    request = Slack::Api::AppsManifestUpdate.new(app_id: "A1", manifest: manifest)
    manifest["display_information"].as_h["name"] = JSON::Any.new("changed")
    request.manifest["display_information"].as_h["name"] = JSON::Any.new("changed again")

    JSON.parse(URI::Params.parse(request.body)["manifest"]).should eq JSON.parse(
      %({"display_information":{"name":"original"}}))
  end
end

describe Slack::Api::AppsManifestExport do
  it "returns the app's manifest as raw JSON" do
    sent = stub_manifest_method("apps.manifest.export", <<-JSON)
      {"ok":true,"manifest":{"_metadata":{"major_version":1,"minor_version":1},
       "display_information":{"name":"hiro.bot"},"settings":{"socket_mode_enabled":true}}}
      JSON

    exported = config_client.call(Slack::Api::AppsManifestExport.new("A012ABCD0A0"))

    sent.should eq [URI::Params.parse("app_id=A012ABCD0A0")]
    exported.manifest["display_information"]["name"].as_s.should eq "hiro.bot"
    exported.manifest["settings"]["socket_mode_enabled"].as_bool.should be_true
  end
end

describe Slack::Api::AppsManifestDelete do
  it "sends the app ID" do
    sent = stub_manifest_method("apps.manifest.delete", %({"ok":true}))

    config_client.call(Slack::Api::AppsManifestDelete.new("A012ABCD0A0")).ok?.should be_true

    sent.should eq [URI::Params.parse("app_id=A012ABCD0A0")]
  end
end
