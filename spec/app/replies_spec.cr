require "../spec_helper"
require "log/spec"
require "../../src/slack/testing"
require "../support/app/signed_request"

# Payloads and expected request bodies are authored independently from:
# https://docs.slack.dev/reference/events/app_mention
# https://docs.slack.dev/reference/events/tokens_revoked
# https://docs.slack.dev/reference/events/app_uninstalled
# https://docs.slack.dev/reference/methods/chat.postMessage
# https://docs.slack.dev/interactivity/handling-user-interaction
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
private MENTION = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"app_mention","user":"U-SYNTHETIC","text":"<@U-BOT> status","ts":"1789232400.000100",
            "channel":"C-SYNTHETIC","event_ts":"1789232400.000100"},
   "type":"event_callback","event_id":"Ev-MENTION","event_time":1789232400,
   "authorizations":[{"team_id":"T-INSTALLED","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

# https://docs.slack.dev/reference/events/reaction_added
private FILE_REACTION = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"reaction_added","user":"U-SYNTHETIC","reaction":"eyes","item_user":"U-UPLOADER",
            "item":{"type":"file","file":"F-SYNTHETIC"},"event_ts":"1789232400.000300"},
   "type":"event_callback","event_id":"Ev-REACTION","event_time":1789232400}
  JSON

# https://docs.slack.dev/reference/events/message
private THREAD_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"C-SYNTHETIC","user":"U-SYNTHETIC","text":"status please",
            "ts":"1789232400.000200","thread_ts":"1789232400.000100","event_ts":"1789232400.000200",
            "channel_type":"channel"},
   "type":"event_callback","event_id":"Ev-THREAD","event_time":1789232400}
  JSON

private TOKENS_REVOKED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"tokens_revoked","tokens":{"oauth":[],"bot":["U-BOT"]}},
   "type":"event_callback","event_id":"Ev-REVOKED","event_time":1789232400,
   "authorizations":[{"team_id":"T-INSTALLED","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private APP_UNINSTALLED = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"app_uninstalled"},
   "type":"event_callback","event_id":"Ev-UNINSTALLED","event_time":1789232400,
   "authorizations":[{"team_id":"T-INSTALLED","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

# The reference example has no `authorizations`.
private TOKENS_REVOKED_WITHOUT_AUTHORIZATIONS = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-INSTALLED","api_app_id":"A-SYNTHETIC",
   "event":{"type":"tokens_revoked","tokens":{"oauth":[],"bot":["U-BOT"]}},
   "type":"event_callback","event_id":"Ev-REVOKED-BARE","event_time":1789232400}
  JSON

private RETRY_HEADERS = HTTP::Headers{"X-Slack-Retry-Num" => "1", "X-Slack-Retry-Reason" => "http_timeout"}

# Fails the first uninstall cleanup with a storage error, as a lost write would.
private class FailingOnceStore < Slack::Auth::MemoryInstallationStore
  @failed = false

  def delete(key : Slack::Auth::InstallationKey, expected : Slack::Auth::Version) : Slack::Auth::InstallationRecord
    unless @failed
      @failed = true
      raise Slack::Auth::ContractError.new(:persistence_failure)
    end
    super
  end
end

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

private MESSAGE_CLICK = <<-JSON
  {"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-INSTALLED","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-INSTALLED"},"trigger_id":"1789232400.synthetic.trigger",
   "container":{"type":"message","message_ts":"1789232400.000100","channel_id":"C-SYNTHETIC","is_ephemeral":false},
   "channel":{"id":"C-SYNTHETIC","name":"deploys"},
   "response_url":"https://hooks.slack.com/actions/T-INSTALLED/2/synthetic",
   "actions":[{"type":"button","action_id":"deploy.approve","block_id":"deploy.actions",
               "text":{"type":"plain_text","text":"Approve"},"value":"api","action_ts":"1789232401.000001"}]}
  JSON

private MODAL_CLICK = <<-JSON
  {"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-INSTALLED","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-INSTALLED"},"trigger_id":"1789232400.synthetic.trigger",
   "container":{"type":"view","view_id":"V-SYNTHETIC"},
   "view":{"id":"V-SYNTHETIC","type":"modal","callback_id":"deploy.form","team_id":"T-INSTALLED"},
   "actions":[{"type":"button","action_id":"deploy.approve","block_id":"deploy.actions",
               "text":{"type":"plain_text","text":"Approve"},"value":"api","action_ts":"1789232401.000001"}]}
  JSON

private POSTED = %({"ok":true,"channel":"C-SYNTHETIC","ts":"1789232400.000900","message":{"type":"message","text":"x","ts":"1789232400.000900"}})

private OWNER = Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: "T-INSTALLED")

private def single_token_app(transport : Slack::Testing::RecordingTransport) : Slack::App
  client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-single"), transport: transport)
  Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client), response_url_transport: transport)
end

private def installed_store(bot : Slack::Auth::Grant = bot_grant) : Slack::Auth::MemoryInstallationStore
  store = Slack::Auth::MemoryInstallationStore.new
  store.store(OWNER, Slack::Auth::InstallationPatch.new(bot: bot), nil)
  store
end

private def bot_grant(expires_at : Time? = nil) : Slack::Auth::Grant
  refresh = expires_at ? Slack::Auth::Secret.new("synthetic-refresh") : nil
  Slack::Auth::Grant.new("U-BOT", Slack::Auth::Secret.new("xoxb-installed-synthetic"), ["chat:write"], expires_at, refresh)
end

private def installation_app(store : Slack::Auth::InstallationStore, transport : Slack::Testing::RecordingTransport,
                             rotation : Slack::Auth::RotationService? = nil) : Slack::App
  request_authorizer = Slack::Auth::RequestAuthorizer.new("A-SYNTHETIC", store, transport,
    Slack::Auth::APIConfiguration.default, AppSupport::VERIFIER, rotation: rotation)
  Slack::App.new(authorizer: Slack::App::InstallationAuthorizer.new(request_authorizer, Slack::Auth::GrantKey.new(:bot)),
    response_url_transport: transport)
end

private def receive(app : Slack::App, request : HTTP::Request) : AppSupport::Reply
  AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER), request)
end

private def json_body(request : Slack::Auth::TransportRequest) : JSON::Any
  JSON.parse(request.body || raise "Missing request body")
end

describe "Slack::App say and respond" do
  it "says a Block Kit reply in the thread of a message when the listener passes thread_ts" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED)
    app = single_token_app(transport)
    done = Channel(String).new(1)
    app.message("status") do |ctx|
      message = Slack::UI.message(fallback_text: "Status: green") do |builder|
        builder.section(Slack::UI.mrkdwn("Status: *green*"), block_id: "status")
      end
      metadata = Slack::UI::MessageMetadata.new("status_reported", {"service" => JSON::Any.new("api")})
      done.send(ctx.say(message, thread_ts: ctx.event.thread_ts, metadata: metadata).ts)
    end

    receive(app, AppSupport.json(THREAD_MESSAGE)).status.should eq 200
    done.receive.should eq "1789232400.000900"

    requests = transport.requests
    requests.size.should eq 1
    requests.first.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    requests.first.headers["Authorization"].should eq "Bearer xoxb-synthetic-single"
    json_body(requests.first).should eq JSON.parse(<<-JSON)
      {"channel":"C-SYNTHETIC","text":"Status: green",
       "blocks":[{"type":"section","block_id":"status","text":{"type":"mrkdwn","text":"Status: *green*"}}],
       "thread_ts":"1789232400.000100",
       "metadata":{"event_type":"status_reported","event_payload":{"service":"api"}}}
      JSON
  end

  it "says plain text in the channel of a slash command without threading it" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(POSTED)
    app = single_token_app(transport)
    done = Channel(Nil).new(1)
    app.command("/deploy") do |ctx|
      ctx.ack
      ctx.say("Deploying #{ctx.command.text}.")
      done.send(nil)
    end

    receive(app, AppSupport.form(COMMAND)).status.should eq 200
    done.receive

    json_body(transport.requests.first).should eq JSON.parse(%({"channel":"C-SYNTHETIC","text":"Deploying api."}))
  end

  it "responds to the exact response_url of a slash command without a token" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond("ok")
    app = single_token_app(transport)
    done = Channel(Nil).new(1)
    app.command("/deploy") do |ctx|
      ctx.ack
      ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Deployed api.", response_type: :in_channel))
      done.send(nil)
    end

    receive(app, AppSupport.form(COMMAND)).status.should eq 200
    done.receive

    requests = transport.requests
    requests.size.should eq 1
    request = requests.first
    request.method.should eq "POST"
    request.uri.to_s.should eq "https://hooks.slack.com/commands/T-INSTALLED/1/synthetic"
    request.headers["Content-Type"].should eq "application/json"
    request.headers["Authorization"]?.should be_nil
    json_body(request).should eq JSON.parse(%({"response_type":"in_channel","text":"Deployed api."}))
  end

  it "replaces the clicked message through the action's response_url" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond("ok")
    app = single_token_app(transport)
    done = Channel(Nil).new(1)
    app.action("deploy.approve") do |ctx|
      ctx.ack
      ctx.respond(Slack::Interactions::ResponseUrlMessage.new(text: "Approved.", replace_original: true))
      done.send(nil)
    end

    receive(app, AppSupport.interaction(MESSAGE_CLICK)).status.should eq 200
    done.receive

    request = transport.requests.first
    request.uri.to_s.should eq "https://hooks.slack.com/actions/T-INSTALLED/2/synthetic"
    json_body(request).should eq JSON.parse(%({"replace_original":true,"text":"Approved."}))
  end

  it "gives the error handler a missing reply target for a click in a modal" do
    transport = Slack::Testing::RecordingTransport.new
    app = single_token_app(transport)
    errors = Channel(Slack::App::ListenerError).new(2)
    app.error { |error, _ctx| errors.send(error) }
    app.action("deploy.approve") do |ctx|
      ctx.ack
      ctx.say("unreachable")
    end

    receive(app, AppSupport.interaction(MODAL_CLICK)).status.should eq 200

    error = errors.receive
    error.cause.should be_a(Slack::App::NoReplyTarget)
    transport.requests.should be_empty
  end

  it "gives the error handler a missing reply target for a reaction on a file" do
    transport = Slack::Testing::RecordingTransport.new
    app = single_token_app(transport)
    errors = Channel(Slack::App::ListenerError).new(2)
    app.error { |error, _ctx| errors.send(error) }
    app.on_reaction_added(&.say("unreachable"))

    receive(app, AppSupport.json(FILE_REACTION)).status.should eq 200

    error = errors.receive
    error.cause.should be_a(Slack::App::NoReplyTarget)
    transport.requests.should be_empty
  end
end

describe "Slack::App error handler" do
  it "receives the credential failure when a revoked grant blocks say" do
    transport = Slack::Testing::RecordingTransport.new
    store = installed_store
    app = installation_app(store, transport)
    errors = Channel({Slack::App::ListenerError, Slack::App::Context}).new(1)
    app.error { |error, ctx| errors.send({error, ctx}) }
    app.event(Slack::Events::AppMentioned) do |ctx|
      record = store.fetch(OWNER) || raise "Missing installation"
      store.invalidate(OWNER, Slack::Auth::GrantKey.new(:bot), record.version)
      ctx.say("unreachable")
    end

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.json(MENTION)).status.should eq 200
      error, context = errors.receive

      error.cause.should be_a(Slack::Auth::ContractError)
      error.payload_kind.should eq "event app_mention"
      error.route.should eq "Slack::App::EventContext(Slack::Events::AppMentioned)"
      error.acknowledged?.should be_true
      error.message.should eq "Listener for Slack::App::EventContext(Slack::Events::AppMentioned) raised Slack::Auth::ContractError after acknowledging"
      context.should be_a(Slack::App::EventContext(Slack::Events::AppMentioned))
      transport.requests.should be_empty
      logs.empty
    end
  end

  it "runs for a listener that raises before it acknowledges; the receiver still answers 500" do
    app = single_token_app(Slack::Testing::RecordingTransport.new)
    errors = Channel(Slack::App::ListenerError).new(1)
    app.error { |error, _ctx| errors.send(error) }
    app.command("/deploy") { |_ctx| raise ArgumentError.new("secret-looking detail") }

    receive(app, AppSupport.form(COMMAND)).status.should eq 500

    error = errors.receive
    error.acknowledged?.should be_false
    error.payload_kind.should eq "command /deploy"
    error.message.to_s.should_not contain "secret-looking detail"
  end

  it "runs the handler after the receiver has the failed outcome" do
    app = single_token_app(Slack::Testing::RecordingTransport.new)
    order = [] of String
    handled = Channel(Nil).new(1)
    app.error do |_error, _ctx|
      order << "handler"
      handled.send(nil)
    end
    app.command("/deploy") { |_ctx| raise "synthetic failure" }

    receive(app, AppSupport.form(COMMAND)).status.should eq 500
    order << "response"
    handled.receive

    order.should eq ["response", "handler"]
  end

  it "logs the exception class when the error handler itself raises" do
    app = single_token_app(Slack::Testing::RecordingTransport.new)
    handled = Channel(Nil).new(1)
    app.error do |_error, _ctx|
      handled.send(nil)
      raise KeyError.new("handler detail")
    end
    app.command("/deploy") { |_ctx| raise "listener detail" }

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.form(COMMAND)).status.should eq 500
      handled.receive
      Fiber.yield
      logs.check(:error, "Error handler raised KeyError for Slack::App::CommandContext")
    end
  end
end

describe "Slack::App authorization" do
  it "rotates an expiring token before the listener's say sends" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(File.read("spec/fixtures/oauth_responses/refresh_bot.json"))
    transport.respond(POSTED)
    store = installed_store(bot_grant(expires_at: Time.utc + 1.minute))
    oauth = Slack::Auth::OAuthConfiguration.new(URI.parse("https://slack.com/oauth/v2/authorize"),
      URI.parse("https://slack.com/api/oauth.v2.access"), "synthetic-client", Slack::Auth::Secret.new("synthetic-client-secret"),
      URI.parse("https://app.example.test/callback"))
    rotation = Slack::Auth::RotationService.new(store, Slack::Auth::RefreshClient.new(oauth, transport))
    app = installation_app(store, transport, rotation)
    done = Channel(Nil).new(1)
    app.on_app_mention do |ctx|
      ctx.say("Rotated.")
      done.send(nil)
    end

    receive(app, AppSupport.json(MENTION)).status.should eq 200
    done.receive

    refresh, post = transport.requests
    refresh.uri.to_s.should eq "https://slack.com/api/oauth.v2.access"
    post.uri.to_s.should eq "https://slack.com/api/chat.postMessage"
    post.headers["Authorization"].should eq "Bearer synthetic-next-bot"
  end

  it "routes tokens_revoked to the credential lifecycle before authorization" do
    transport = Slack::Testing::RecordingTransport.new
    store = installed_store
    app = installation_app(store, transport)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER))
    ran = false
    app.on_tokens_revoked { |_ctx| ran = true }

    reply = receive(app, AppSupport.json(TOKENS_REVOKED))

    reply.status.should eq 200
    reply.body.should be_empty
    record = store.fetch(OWNER).should_not be_nil
    record.bot.should be_nil
    ran.should be_false
    transport.requests.should be_empty
  end

  it "removes the installation for app_uninstalled" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER))

    receive(app, AppSupport.json(APP_UNINSTALLED)).status.should eq 200

    record = store.fetch(OWNER)
    (record.nil? || record.deleted?).should be_true
  end

  it "keeps a reinstall when Slack repeats an applied uninstall" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER))
    receive(app, AppSupport.json(APP_UNINSTALLED)).status.should eq 200
    tombstone = store.fetch(OWNER).should_not be_nil
    reinstalled = store.store(OWNER, Slack::Auth::InstallationPatch.new(bot: bot_grant), tombstone.version)

    receive(app, AppSupport.json(APP_UNINSTALLED, RETRY_HEADERS)).status.should eq 200

    record = store.fetch(OWNER).should_not be_nil
    record.deleted?.should be_false
    record.version.should eq reinstalled.version
  end

  it "retries a failed cleanup with its original preparation" do
    store = FailingOnceStore.new
    store.store(OWNER, Slack::Auth::InstallationPatch.new(bot: bot_grant), nil)
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER))

    receive(app, AppSupport.json(APP_UNINSTALLED)).status.should eq 500
    receive(app, AppSupport.json(APP_UNINSTALLED, RETRY_HEADERS)).status.should eq 200

    record = store.fetch(OWNER)
    (record.nil? || record.deleted?).should be_true
  end

  it "does not prepare a retry that it has no preparation for" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER))

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.json(APP_UNINSTALLED, RETRY_HEADERS)).status.should eq 200
      logs.check(:warn, "Skipped credential cleanup for event app_uninstalled: a retry without a retained preparation")
    end
    store.fetch(OWNER).should_not(be_nil).deleted?.should be_false
  end

  it "uses the selected owner for a revocation without authorizations" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    lifecycle = Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER)
    app.lifecycle(lifecycle) do |envelope|
      Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: envelope.team_id)
    end

    receive(app, AppSupport.json(TOKENS_REVOKED_WITHOUT_AUTHORIZATIONS)).status.should eq 200

    store.fetch(OWNER).should_not(be_nil).bot.should be_nil
  end

  it "rejects a selected owner of another workspace" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    lifecycle = Slack::Auth::CredentialLifecycle.new("A-SYNTHETIC", store, AppSupport::VERIFIER)
    app.lifecycle(lifecycle) { |_envelope| Slack::Auth::InstallationKey.new("A-SYNTHETIC", :workspace, team_id: "T-OTHER") }

    receive(app, AppSupport.json(TOKENS_REVOKED_WITHOUT_AUTHORIZATIONS)).status.should eq 500

    store.fetch(OWNER).should_not(be_nil).bot.should_not be_nil
  end

  it "answers 500 when the lifecycle cannot apply the event, without logging the payload" do
    store = installed_store
    app = installation_app(store, Slack::Testing::RecordingTransport.new)
    app.lifecycle(Slack::Auth::CredentialLifecycle.new("A-OTHER", store, AppSupport::VERIFIER))

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.json(TOKENS_REVOKED)).status.should eq 500
      logs.check(:error, "Credential cleanup for event tokens_revoked raised Slack::Auth::RequestAuthorizationError")
    end
    store.fetch(OWNER).try(&.bot).should_not be_nil
  end
end
