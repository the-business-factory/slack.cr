require "../spec_helper"
require "log/spec"
require "../../src/slack/testing"
require "../support/app/signed_request"

# The token exchange bodies are authored from https://docs.slack.dev/reference/methods/oauth.v2.access.
private EXCHANGE = <<-JSON
  {"ok":true,"access_token":"xoxb-synthetic-installed","token_type":"bot","scope":"commands,chat:write",
   "bot_user_id":"U-BOT","app_id":"A-SYNTHETIC","team":{"id":"T-INSTALLED","name":"Synthetic"},
   "authed_user":{"id":"U-INSTALLER"}}
  JSON
private INVALID_CODE = %({"ok":false,"error":"invalid_code"})

# Slash command form fields are authored from https://docs.slack.dev/interactivity/implementing-slash-commands.
private COMMAND = {
  "token"        => "synthetic-legacy-token",
  "team_id"      => "T-SYNTHETIC",
  "team_domain"  => "synthetic",
  "channel_id"   => "C-SYNTHETIC",
  "channel_name" => "deploys",
  "user_id"      => "U-SYNTHETIC",
  "user_name"    => "synthetic.user",
  "command"      => "/deploy",
  "text"         => "api",
  "api_app_id"   => "A-SYNTHETIC",
  "response_url" => "https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",
  "trigger_id"   => "1789232400.synthetic.trigger",
}

private def oauth : Slack::Auth::OAuthConfiguration
  Slack::Auth::OAuthConfiguration.new(
    URI.parse("https://slack.com/oauth/v2/authorize"), URI.parse("https://slack.com/api/oauth.v2.access"),
    "synthetic-client-id", Slack::Auth::Secret.new("synthetic-client-secret"),
    URI.parse("https://app.example.test/slack/oauth_redirect"))
end

private class InstallRecorder
  getter installed = [] of String
  getter failures = [] of Exception
  property session : String? = "session-1"
end

private def routes(transport : Slack::Testing::RecordingTransport, recorder : InstallRecorder = InstallRecorder.new) : Slack::App::InstallRoutes
  handler = Slack::AuthHandler.new(oauth, Slack::Auth::MemoryStateStore.new, transport, bot_scopes: ["commands"])
  Slack::App::InstallRoutes.new(handler,
    session_binding: ->(_context : HTTP::Server::Context) : Slack::Auth::Secret? {
      recorder.session.try { |value| Slack::Auth::Secret.new(value) }
    },
    on_installed: ->(response : Slack::AuthResponse) : String {
      recorder.installed << response.installation_key.team_id.to_s
      "/installed"
    },
    on_failed: ->(error : Exception) : String {
      recorder.failures << error
      "/install/failed"
    })
end

private def get(handler : HTTP::Handler, path : String) : AppSupport::Reply
  AppSupport.run(handler, HTTP::Request.new("GET", path))
end

private def issued_state(handler : HTTP::Handler) : String
  URI.parse(get(handler, "/slack/install").headers["Location"]).query_params["state"]
end

describe Slack::App::InstallRoutes do
  it "redirects the install route to Slack with state bound to the session" do
    reply = get(routes(Slack::Testing::RecordingTransport.new), "/slack/install")

    reply.status.should eq 302
    location = URI.parse(reply.headers["Location"])
    location.host.should eq "slack.com"
    location.path.should eq "/oauth/v2/authorize"
    location.query_params["client_id"].should eq "synthetic-client-id"
    location.query_params["scope"].should eq "commands"
    location.query_params["state"].should_not be_empty
  end

  it "answers 400 on both routes when the application has no session for the browser" do
    transport = Slack::Testing::RecordingTransport.new
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    state = issued_state(handler)
    recorder.session = nil

    get(handler, "/slack/install").status.should eq 400
    get(handler, "/slack/oauth_redirect?code=synthetic-code&state=#{state}").status.should eq 400
    transport.requests.should be_empty
    recorder.failures.should be_empty
  end

  it "exchanges the code on the callback and redirects to the application" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(EXCHANGE)
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    state = issued_state(handler)

    reply = get(handler, "/slack/oauth_redirect?code=synthetic-code&state=#{state}")

    reply.status.should eq 302
    reply.headers["Location"].should eq "/installed"
    recorder.installed.should eq ["T-INSTALLED"]
    exchange = transport.requests.first
    exchange.uri.path.should eq "/api/oauth.v2.access"
    URI::Params.parse(exchange.body.should_not(be_nil))["code"].should eq "synthetic-code"
  end

  it "redirects to the failure path when Slack denies the install, and the state stays spent" do
    transport = Slack::Testing::RecordingTransport.new
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    state = issued_state(handler)

    denied = get(handler, "/slack/oauth_redirect?error=access_denied&state=#{state}")
    replayed = get(handler, "/slack/oauth_redirect?code=synthetic-code&state=#{state}")

    denied.status.should eq 302
    denied.headers["Location"].should eq "/install/failed"
    replayed.headers["Location"].should eq "/install/failed"
    transport.requests.should be_empty
    recorder.installed.should be_empty
    recorder.failures.map { |error| error.should(be_a(Slack::Auth::ContractError)).code }.should eq [
      Slack::Auth::ErrorCode::ReauthorizationRequired, Slack::Auth::ErrorCode::InvalidState,
    ]
  end

  it "rejects a callback from a different session without an exchange" do
    transport = Slack::Testing::RecordingTransport.new
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    state = issued_state(handler)
    recorder.session = "session-2"

    get(handler, "/slack/oauth_redirect?code=synthetic-code&state=#{state}").headers["Location"].should eq "/install/failed"
    transport.requests.should be_empty
  end

  it "redirects to the failure path when the exchange fails and logs only the error class" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(INVALID_CODE)
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    state = issued_state(handler)

    Log.capture("slack.app.install") do |logs|
      reply = get(handler, "/slack/oauth_redirect?code=synthetic-code&state=#{state}")

      reply.headers["Location"].should eq "/install/failed"
      recorder.failures.first.should be_a(Slack::Auth::ResponseError)
      entry = logs.check(:warn, /Slack::Auth::ResponseError/).entry
      entry.message.should_not contain(state)
      entry.message.should_not contain("synthetic-code")
      entry.message.should_not contain("invalid_code")
    end
  end

  it "passes other paths and methods to the next handler" do
    transport = Slack::Testing::RecordingTransport.new
    recorder = InstallRecorder.new
    handler = routes(transport, recorder)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(
      Slack::Api::Client.new(token: "xoxb-synthetic", transport: Slack::Testing::RecordingTransport.new)))
    app.command("/deploy") { |ctx| ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}.")) }
    handler.next = Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER)

    reply = AppSupport.run(handler, AppSupport.form(COMMAND))
    JSON.parse(reply.body).should eq JSON.parse(%({"response_type":"ephemeral","text":"Deploying api."}))
    AppSupport.run(handler, HTTP::Request.new("POST", "/slack/install")).status.should eq 404
    transport.requests.should be_empty
    recorder.failures.should be_empty
  end
end
