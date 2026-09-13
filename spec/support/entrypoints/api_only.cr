require "slack"
require "webmock"
require "../auth/webmock_transport"

# No OAuth or webhook credential is needed to configure and use a token API wrapper.
Habitat.raise_if_missing_settings!
WebMock.stub(:get, "https://slack.com/api/team.info")
  .with(headers: {"Authorization" => "Bearer synthetic-token"})
  .to_return(body: File.read("spec/fixtures/api/team-info-success.json"))

team = Slack::Api::TeamInfo.new(
  "synthetic-token",
  transport: AuthSupport::WebMockTransport.new
).call
raise "Unexpected API response" unless team.name == "goalsurfer"
