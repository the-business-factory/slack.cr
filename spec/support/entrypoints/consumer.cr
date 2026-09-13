require "webmock"
require "../auth/webmock_transport"

# This consumer runs without spec_helper, dotenv, or redirect environment values.
Slack.configure do |config|
  config.client_id = "dummy-client"
  config.client_secret = "dummy-secret"
  config.signing_secret = "dummy-signing-secret"
end
Habitat.raise_if_missing_settings!
raise "Unexpected login redirect" unless Slack::SignInWithSlack.settings.sign_in_redirect_url.nil?

WebMock.stub(:get, "https://slack.com/api/team.info")
  .with(headers: {"Authorization" => "Bearer dummy-token"})
  .to_return(body: File.read("spec/fixtures/api/team-info-success.json"))
team = Slack::Api::TeamInfo.new("dummy-token", transport: AuthSupport::WebMockTransport.new).call
raise "Unexpected API response" unless team.name == "goalsurfer"

class ConsumerOAuthTransport < Slack::Auth::Transport
  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise "Incorrect token endpoint" unless request.uri == URI.parse("https://oauth.example.test/token")
    form = URI::Params.parse(request.body || raise "Missing form")
    raise "Incorrect code" unless form["code"] == "dummy+code&value"
    raise "Incorrect client ID" unless form["client_id"] == "dummy-client"
    raise "Incorrect client secret" unless form["client_secret"] == "dummy-secret"
    expected = "https://example.test/install?tenant=one&route=a+b%2Fc"
    raise "Incorrect exchange redirect" unless form["redirect_uri"] == expected
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/auth_success.json"))
  end
end

redirect = "https://example.test/install?tenant=one&route=a+b%2Fc"
configuration = Slack::Auth::OAuthConfiguration.new(
  URI.parse("https://oauth.example.test/authorize"),
  URI.parse("https://oauth.example.test/token"),
  "dummy-client",
  Slack::Auth::Secret.new("dummy-secret"),
  URI.parse(redirect)
)
state_store = Slack::Auth::MemoryStateStore.new
handler = Slack::AuthHandler.new(configuration, state_store, ConsumerOAuthTransport.new,
  bot_scopes: ["commands"], user_scopes: ["users:read"])
session_binding = Slack::Auth::Secret.new("trusted-browser-session")
authorization = URI.parse(handler.redirect_url(session_binding))
raise "Incorrect installation redirect" unless authorization.query_params["redirect_uri"] == redirect
state = authorization.query_params["state"]
callback_query = URI::Params.encode({"code" => "dummy+code&value", "state" => state})
callback = HTTP::Request.new("GET", "/install?#{callback_query}")
installation = handler.authenticate_user(callback, session_binding)
raise "Unexpected installation" unless installation.team.try(&.id) == "T9TK3CUKW"
raise "Installation configured login" unless Slack::SignInWithSlack.settings.sign_in_redirect_url.nil?

Slack::SignInWithSlack.configure(&.sign_in_redirect_url=("https://example.test/login"))
login = URI.parse(Slack::SignInWithSlack.new.redirect_url)
raise "Incorrect login redirect" unless login.query_params["redirect_uri"] == "https://example.test/login"

# Keep the original positional constructor and public query helper callable.
history = Slack::Api::ConversationsHistory.new("dummy-token", "C1", "next +", false, false, "123", "100")
expected_query = "channel=C1&cursor=next+%2B&include_all_metadata=false&inclusive=false&latest=123&oldest=100"
raise "History query helper changed" unless history.url_params == expected_query
raise "History query hooks differ" unless history.query == history.url_params
