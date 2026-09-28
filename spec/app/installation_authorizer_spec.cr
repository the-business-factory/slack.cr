require "../spec_helper"
require "../../src/slack/testing"
require "../support/app/signed_request"

private def command(team_id : String) : HTTP::Request
  AppSupport.form({
    "token"        => "synthetic-legacy-token",
    "team_id"      => team_id,
    "team_name"    => "synthetic",
    "channel_id"   => "C-SYNTHETIC",
    "channel_name" => "deploys",
    "user_id"      => "U-SYNTHETIC",
    "user_name"    => "synthetic.user",
    "command"      => "/deploy",
    "text"         => "api",
    "api_app_id"   => "A-SYNTHETIC",
    "response_url" => "https://hooks.slack.com/commands/#{team_id}/1/synthetic",
    "trigger_id"   => "1789232400.synthetic.trigger",
  })
end

private def installation_app(transport : Slack::Testing::RecordingTransport = Slack::Testing::RecordingTransport.new) : Slack::App
  store = Slack::Auth::MemoryInstallationStore.new
  owner = Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: "T-INSTALLED")
  bot = Slack::Auth::Grant.new("U-BOT", Slack::Auth::Secret.new("xoxb-installed-synthetic"), ["chat:write"])
  store.store(owner, Slack::Auth::InstallationPatch.new(bot: bot), nil)
  request_authorizer = Slack::Auth::RequestAuthorizer.new("A-SYNTHETIC", store, transport,
    Slack::Auth::APIConfiguration.default, AppSupport::VERIFIER)
  Slack::App.new(authorizer: Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot)))
end

describe Slack::App::InstallationAuthorizer do
  it "gives the listener a client that sends the owning installation's bot token" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true,"channel":"C-SYNTHETIC","ts":"1789232400.000300"}))
    app = installation_app(transport)
    posted = Channel(String).new(1)
    app.command("/deploy") do |ctx|
      ctx.ack
      result = ctx.client.call("chat.postMessage", {channel: ctx.command.channel_id, text: "Deploying."})
      posted.send(result["ts"].as_s)
    end

    AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), command("T-INSTALLED")).status.should eq 200
    posted.receive.should eq "1789232400.000300"
    requests = transport.requests
    requests.size.should eq 1
    request = requests.first
    request.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    request.headers["Authorization"].should eq "Bearer xoxb-installed-synthetic"
  end

  it "answers 401 and runs no listener for a workspace without an installation" do
    app = installation_app
    ran = false
    app.command("/deploy") { |_ctx| ran = true }

    reply = AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), command("T-UNKNOWN"))

    reply.status.should eq 401
    ran.should be_false
  end
end
