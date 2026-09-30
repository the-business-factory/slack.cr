# Run with: crystal run examples/install_routes.cr
# Serves the OAuth install and callback routes on a local HTTP server. A recording
# transport answers the token exchange, so the example makes no Slack calls.
require "http/client"
require "../src/slack"
require "../src/slack/testing"

oauth = Slack::Auth::OAuthConfiguration.new(
  URI.parse("https://slack.com/oauth/v2/authorize"),
  URI.parse("https://slack.com/api/oauth.v2.access"),
  "synthetic-client-id",
  Slack::Auth::Secret.new("synthetic-client-secret"),
  URI.parse("https://app.example.test/slack/oauth_redirect"))

# Token exchange response, authored from https://docs.slack.dev/reference/methods/oauth.v2.access.
transport = Slack::Testing::RecordingTransport.new
transport.respond(<<-JSON)
  {"ok":true,"access_token":"xoxb-synthetic-installed","token_type":"bot","scope":"commands",
   "bot_user_id":"U-BOT","app_id":"A-SYNTHETIC","team":{"id":"T-INSTALLED","name":"Synthetic"},
   "authed_user":{"id":"U-INSTALLER"}}
  JSON
handler = Slack::AuthHandler.new(oauth, Slack::Auth::MemoryStateStore.new, transport, bot_scopes: ["commands"])
store = Slack::Auth::MemoryInstallationStore.new

routes = Slack::App::InstallRoutes.new(handler,
  # A real application reads this from its trusted server session.
  session_binding: ->(_context : HTTP::Server::Context) : Slack::Auth::Secret? {
    Slack::Auth::Secret.new("example-session")
  },
  on_installed: ->(response : Slack::AuthResponse) : String {
    store.store(response.installation_key, response.installation_patch(Slack::Auth::SystemClock.new), nil)
    "/installed"
  },
  on_failed: ->(_error : Exception) : String { "/install/failed" })

# Events, commands, and interactions go on to the HTTP receiver.
client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: Slack::Testing::RecordingTransport.new)
app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
app.command("/deploy") { |ctx| ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}.")) }
receiver = Slack::App::HttpReceiver.new(app, Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new("synthetic-signing-secret")))

server = HTTP::Server.new([routes, receiver])
address = server.bind_tcp("127.0.0.1", 0)
spawn { server.listen }

HTTP::Client.new(address.address, address.port) do |browser|
  install = browser.get("/slack/install")
  location = install.headers["Location"]
  puts "GET /slack/install -> #{install.status_code} #{location}"

  state = URI.parse(location).query_params["state"]
  callback = browser.get("/slack/oauth_redirect?code=synthetic-code&state=#{state}")
  puts "GET /slack/oauth_redirect -> #{callback.status_code} #{callback.headers["Location"]}"
end
server.close
