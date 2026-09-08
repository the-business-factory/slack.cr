require "webmock"

# This consumer runs without spec_helper, dotenv, or redirect environment values.
Slack.configure do |config|
  config.client_id = "dummy-client"
  config.client_secret = "dummy-secret"
  config.signing_secret = "dummy-signing-secret"
end
Habitat.raise_if_missing_settings!
raise "Unexpected installation redirect" unless Slack::AuthHandler.settings.oauth_redirect_url.nil?
raise "Unexpected login redirect" unless Slack::SignInWithSlack.settings.sign_in_redirect_url.nil?

WebMock.stub(:get, "https://slack.com/api/team.info")
  .with(headers: {"Authorization" => "Bearer dummy-token"})
  .to_return(body: File.read("spec/fixtures/api/team-info-success.json"))
team = Slack::Api::TeamInfo.new("dummy-token").call
raise "Unexpected API response" unless team.name == "goalsurfer"

redirect = "https://example.test/install?tenant=one&route=a+b%2Fc"
Slack::AuthHandler.configure(&.oauth_redirect_url=(redirect))
Habitat.raise_if_missing_settings!
authorization = URI.parse(Slack::AuthHandler.new.redirect_url)
raise "Incorrect installation redirect" unless authorization.query_params["redirect_uri"] == redirect
WebMock.stub(:post, "https://slack.com/api/oauth.v2.access")
  .with(headers: {"Content-Type" => "application/x-www-form-urlencoded"})
  .to_return do |request|
    form = URI::Params.parse(request.body.try(&.gets_to_end) || raise "Missing form")
    raise "Incorrect code" unless form["code"] == "dummy+code&value"
    raise "Incorrect client ID" unless form["client_id"] == "dummy-client"
    raise "Incorrect client secret" unless form["client_secret"] == "dummy-secret"
    raise "Incorrect exchange redirect" unless form["redirect_uri"] == redirect
    HTTP::Client::Response.new(200, body: File.read("spec/fixtures/auth_success.json"))
  end
installation = Slack::AuthHandler.run(HTTP::Request.new("GET", "/install?code=dummy%2Bcode%26value"))
raise "Unexpected installation" unless installation.team.try(&.id) == "T9TK3CUKW"
raise "Installation configured login" unless Slack::SignInWithSlack.settings.sign_in_redirect_url.nil?

Slack::SignInWithSlack.configure(&.sign_in_redirect_url=("https://example.test/login"))
login = URI.parse(Slack::SignInWithSlack.new.redirect_url)
raise "Incorrect login redirect" unless login.query_params["redirect_uri"] == "https://example.test/login"
