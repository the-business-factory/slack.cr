require "../../src/slack"
require "webmock"
require "./webmock_transport"

# Validates an app manifest with an app configuration token, fixes the problem
# that Slack reports, creates the app, and exports its manifest again.
module OfflineAppManifestExample
  MANIFEST = <<-JSON
    {"display_information":{"name":"Deploy Bot"},
     "features":{"bot_user":{"display_name":"deploybot"}},
     "oauth_config":{"scopes":{"bot":["app_mentions:read","chat:write"]}},
     "settings":{"event_subscriptions":{"bot_events":["app_mention"]}}}
    JSON

  # Returns the method and form of each request that the example sent, in order.
  def self.run(output : IO = STDOUT) : Array({String, URI::Params})
    WebMock.allow_net_connect = false
    client = Slack::Api::Client.new(token: "xoxe.xoxp-synthetic-config",
      transport: OfflineExample::WebMockTransport.new)
    sent = stub_manifest_methods
    manifest = JSON.parse(MANIFEST)

    begin
      client.call(Slack::Api::AppsManifestValidate.new(manifest))
    rescue error : Slack::Api::Error
      raise error unless error.code == "invalid_manifest"
      error.details.each { |detail| output.puts "#{detail.pointer}: #{detail.message}" }
      manifest = JSON.parse(MANIFEST.sub(%("settings":{), %("settings":{"socket_mode_enabled":true,)))
    end
    client.call(Slack::Api::AppsManifestValidate.new(manifest))
    output.puts "Manifest is valid"

    app = client.call(Slack::Api::AppsManifestCreate.new(manifest))
    output.puts "Created #{app.app_id} with client ID #{app.credentials.client_id}"
    output.puts "Signing secret: #{app.credentials.signing_secret}"

    exported = client.call(Slack::Api::AppsManifestExport.new(app.app_id)).manifest
    output.puts "Exported #{exported["display_information"]["name"]}"
    sent
  end

  # Slack reports each manifest problem with a JSON pointer.
  private def self.stub_manifest_methods : Array({String, URI::Params})
    sent = [] of {String, URI::Params}
    responses = {
      "apps.manifest.validate" => [
        %({"ok":false,"error":"invalid_manifest","errors":[{"message":"Event Subscription requires either Request URL or Socket Mode Enabled","pointer":"/settings/event_subscriptions"}]}),
        %({"ok":true,"errors":[]}),
      ],
      "apps.manifest.create" => [<<-JSON],
        {"ok":true,"app_id":"A0DEPLOY01","credentials":{"client_id":"1234.5678",
         "client_secret":"synthetic-client-secret","verification_token":"synthetic-verification",
         "signing_secret":"synthetic-signing-secret"},
         "oauth_authorize_url":"https://slack.com/oauth/v2/authorize?client_id=1234.5678&scope=app_mentions:read,chat:write"}
        JSON
      "apps.manifest.export" => [
        %({"ok":true,"manifest":{"display_information":{"name":"Deploy Bot"},"settings":{"socket_mode_enabled":true}}}),
      ],
    }
    responses.each do |method, bodies|
      WebMock.stub(:post, "https://slack.com/api/#{method}").to_return do |request|
        sent << {method, URI::Params.parse(request.body.to_s)}
        HTTP::Client::Response.new(200, body: bodies.shift)
      end
    end
    sent
  end
end
