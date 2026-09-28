require "../spec_helper"
require "../../src/slack/testing"
require "../support/app/signed_request"

# Payloads and expected request bodies are authored independently from:
# https://docs.slack.dev/interactivity/implementing-slash-commands
# https://docs.slack.dev/reference/methods/chat.postMessage
# https://docs.slack.dev/authentication/tokens
private COMMAND = {
  "token"        => "synthetic-legacy-token",
  "team_id"      => "T-INSTALLED",
  "team_name"    => "synthetic",
  "channel_id"   => "C-SYNTHETIC",
  "channel_name" => "deploys",
  "user_id"      => "U-SYNTHETIC",
  "user_name"    => "synthetic.user",
  "command"      => "/deploy",
  "text"         => "api",
  "api_app_id"   => "A-SYNTHETIC",
  "response_url" => "https://hooks.slack.com/commands/T-INSTALLED/1/synthetic",
  "trigger_id"   => "1789232400.synthetic.trigger",
}

private POSTED = %({"ok":true,"channel":"C-SYNTHETIC","ts":"1789232400.000900","message":{"type":"message","text":"x","ts":"1789232400.000900"}})

private OWNER      = Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: "T-INSTALLED")
private USER_GRANT = Slack::Auth::GrantKey.new(:user, "U-SYNTHETIC")

private def installed_store : Slack::Auth::MemoryInstallationStore
  bot = Slack::Auth::Grant.new("U-BOT", Slack::Auth::Secret.new("xoxb-installed-synthetic"), ["chat:write"])
  user = Slack::Auth::Grant.new("U-SYNTHETIC", Slack::Auth::Secret.new("xoxp-user-synthetic"), ["chat:write"])
  store = Slack::Auth::MemoryInstallationStore.new
  store.store(OWNER, Slack::Auth::InstallationPatch.new(bot: bot, users: {"U-SYNTHETIC" => user}), nil)
  store
end

private def installation_app(store : Slack::Auth::InstallationStore, transport : Slack::Testing::RecordingTransport) : Slack::App
  request_authorizer = Slack::Auth::RequestAuthorizer.new("A-SYNTHETIC", store, transport,
    Slack::Auth::APIConfiguration.default, AppSupport::VERIFIER)
  authorizer = Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot))
  Slack::App.new(authorizer: authorizer, response_url_transport: transport)
end

private def single_token_app(transport : Slack::Testing::RecordingTransport) : Slack::App
  client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-single"), transport: transport)
  Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client), response_url_transport: transport)
end

private def receive(app : Slack::App) : AppSupport::Reply
  AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), AppSupport.form(COMMAND))
end

private def post(client : Slack::Api::Client, text : String) : Nil
  client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", text: text))
end

# Fails the spec instead of waiting forever when the listener sends nothing.
private def receive_soon(channel : Channel(T)) : T forall T
  select
  when value = channel.receive
    value
  when timeout(1.second)
    fail "the listener did not finish"
  end
end

describe "Slack::App::Context#client with a grant" do
  it "sends the user's token for the user grant and the bot token for the app client" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED).respond(POSTED)
    app = installation_app(installed_store, transport)
    done = Channel(Nil).new(1)
    app.command("/deploy") do |ctx|
      ctx.ack
      post(ctx.client(Slack::Auth::GrantKey.new(:user, ctx.command.user_id)), "Deploying api for myself.")
      post(ctx.client, "Deploy started.")
      done.send(nil)
    end

    receive(app).status.should eq 200
    receive_soon(done)

    requests = transport.requests
    requests.size.should eq 2
    as_user, as_bot = requests
    as_user.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    as_user.headers["Authorization"].should eq "Bearer xoxp-user-synthetic"
    JSON.parse(as_user.body.should_not(be_nil)).should eq JSON.parse(%({"channel":"C-SYNTHETIC","text":"Deploying api for myself."}))
    as_bot.headers["Authorization"].should eq "Bearer xoxb-installed-synthetic"
    JSON.parse(as_bot.body.should_not(be_nil)).should eq JSON.parse(%({"channel":"C-SYNTHETIC","text":"Deploy started."}))
  end

  it "checks the user grant again before each send" do
    transport = Slack::Testing::RecordingTransport.new
    store = installed_store
    app = installation_app(store, transport)
    errors = Channel(Slack::App::ListenerError).new(1)
    app.error { |error, _ctx| errors.send(error) }
    app.command("/deploy") do |ctx|
      ctx.ack
      client = ctx.client(USER_GRANT)
      record = store.fetch(OWNER) || raise "Missing installation"
      store.invalidate(OWNER, USER_GRANT, record.version)
      post(client, "unreachable")
    end

    receive(app).status.should eq 200

    receive_soon(errors).cause.should be_a(Slack::Auth::ContractError)
    transport.requests.should be_empty
  end

  it "gives the error handler a credential failure for a user who did not install" do
    transport = Slack::Testing::RecordingTransport.new
    app = installation_app(installed_store, transport)
    errors = Channel(Slack::App::ListenerError).new(1)
    app.error { |error, _ctx| errors.send(error) }
    app.command("/deploy") do |ctx|
      ctx.ack
      post(ctx.client(Slack::Auth::GrantKey.new(:user, "U-OTHER")), "unreachable")
    end

    receive(app).status.should eq 200

    receive_soon(errors).cause.should be_a(Slack::Auth::ContractError)
    transport.requests.should be_empty
  end

  it "raises GrantUnavailable in single-token mode for a grant other than its own" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED)
    app = single_token_app(transport)
    errors = Channel(Slack::App::ListenerError).new(1)
    app.error { |error, _ctx| errors.send(error) }
    app.command("/deploy") do |ctx|
      ctx.ack
      post(ctx.client(Slack::Auth::GrantKey.new(:bot)), "Deploy started.")
      ctx.client(USER_GRANT)
    end

    receive(app).status.should eq 200

    unavailable = receive_soon(errors).cause.should be_a(Slack::App::GrantUnavailable)
    unavailable.grant.should eq USER_GRANT
    unavailable.payload_kind.should eq "command /deploy"
    unavailable.message.should eq "No client for the user grant of U-SYNTHETIC for command /deploy"
    requests = transport.requests
    requests.size.should eq 1
    requests.first.headers["Authorization"].should eq "Bearer xoxb-synthetic-single"
  end

  it "uses a single-token client built for a user grant only for that grant" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED)
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxp-synthetic-single"), transport: transport)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client, USER_GRANT))
    done = Channel(Nil).new(1)
    app.command("/deploy") do |ctx|
      ctx.ack
      post(ctx.client(USER_GRANT), "Deploying api for myself.")
      done.send(nil)
    end

    receive(app).status.should eq 200
    receive_soon(done)

    transport.requests.first.headers["Authorization"].should eq "Bearer xoxp-synthetic-single"
  end
end
