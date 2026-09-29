require "../spec_helper"
require "log/spec"
require "../support/api/webmock_client"
require "../support/app/signed_request"

# Payloads below are authored independently from the Slack references:
# https://docs.slack.dev/reference/events/app_mention
# https://docs.slack.dev/reference/events/url_verification
# https://docs.slack.dev/interactivity/implementing-slash-commands
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
# https://docs.slack.dev/reference/interaction-payloads/block_suggestion-payload
# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload
# https://docs.slack.dev/reference/interaction-payloads/shortcuts-interaction-payload
private APP_MENTION = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"app_mention","user":"U-SYNTHETIC","text":"<@U-BOT> deploy","ts":"1789232400.000100",
            "channel":"C-SYNTHETIC","event_ts":"1789232400.000100"},
   "type":"event_callback","event_id":"Ev-SYNTHETIC","event_time":1789232400,
   "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
  JSON

private MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","channel":"C-SYNTHETIC","user":"U-SYNTHETIC","text":"please deploy api",
            "ts":"1789232400.000200","event_ts":"1789232400.000200","channel_type":"channel","team":"T-SYNTHETIC"},
   "type":"event_callback","event_id":"Ev-MESSAGE","event_time":1789232400}
  JSON

# https://docs.slack.dev/reference/events/message/ekm_access_denied
private UNMAPPED_SUBTYPE_MESSAGE = <<-JSON
  {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
   "event":{"type":"message","subtype":"ekm_access_denied","channel":"C-SYNTHETIC","user":"UREVOKEDU",
            "text":"Your message couldn't be sent because your team's key has been revoked.",
            "ts":"1789232400.000400","event_ts":"1789232400.000400","channel_type":"channel"},
   "type":"event_callback","event_id":"Ev-SUBTYPE","event_time":1789232400}
  JSON
private URL_VERIFICATION = %({"token":"synthetic-legacy-token","challenge":"3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P","type":"url_verification"})

private COMMAND = {
  "token"        => "synthetic-legacy-token",
  "team_id"      => "T-SYNTHETIC",
  "team_name"    => "synthetic",
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

private BLOCK_ACTIONS = <<-JSON
  {"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
   "container":{"type":"message","message_ts":"1789232400.000100","channel_id":"C-SYNTHETIC","is_ephemeral":false},
   "channel":{"id":"C-SYNTHETIC","name":"deploys"},
   "actions":[{"type":"button","action_id":"deploy.approve","block_id":"deploy.actions",
               "text":{"type":"plain_text","text":"Approve"},"value":"api","action_ts":"1789232401.000001"}]}
  JSON

private BLOCK_SUGGESTION = <<-JSON
  {"type":"block_suggestion","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"action_id":"service.pick","block_id":"service",
   "value":"ap","container":{"type":"view","view_id":"V-SYNTHETIC"}}
  JSON

private VIEW_SUBMISSION = <<-JSON
  {"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
   "view":{"id":"V-SYNTHETIC","type":"modal","callback_id":"deploy.form","team_id":"T-SYNTHETIC",
           "state":{"values":{"reason":{"reason.text":{"type":"plain_text_input","value":"x"}}}}},
   "response_urls":[]}
  JSON

private VIEW_CLOSED = <<-JSON
  {"type":"view_closed","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
   "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},
   "view":{"id":"V-SYNTHETIC","type":"modal","callback_id":"deploy.form","team_id":"T-SYNTHETIC"},
   "is_cleared":false}
  JSON

private MESSAGE_SHORTCUT = <<-JSON
  {"type":"message_action","callback_id":"deploy.from_message","api_app_id":"A-SYNTHETIC",
   "team":{"id":"T-SYNTHETIC","domain":"synthetic"},"user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},
   "channel":{"id":"C-SYNTHETIC","name":"deploys"},"message_ts":"1789232400.000100",
   "trigger_id":"1789232400.synthetic.trigger","response_url":"https://hooks.slack.com/app/T-SYNTHETIC/1/synthetic"}
  JSON

private class FailingAuthorizer < Slack::App::Authorizer
  def authorize(payload : Slack::App::Payload) : Slack::Api::Client
    raise Slack::Auth::ContractError.new(:missing_installation)
  end

  def authorize(payload : Slack::App::Payload, grant : Slack::Auth::GrantKey) : Slack::Api::Client
    raise Slack::Auth::ContractError.new(:missing_installation)
  end
end

private def build_app(ack_timeout : Time::Span = 2.5.seconds, authorizer : Slack::App::Authorizer? = nil) : Slack::App
  Slack::App.new(authorizer: authorizer || Slack::App::SingleTokenAuthorizer.new(ApiSupport.client), ack_timeout: ack_timeout)
end

private def receive(app : Slack::App, request : HTTP::Request,
                    decoder : Slack::Decoder = Slack::Decoder.default) : AppSupport::Reply
  AppSupport.run(Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER, decoder: decoder), request)
end

# A default decoder that records the kind and body of each payload it gets.
private def observing_decoder(observed : Array({Slack::Decoder::Kind, String})) : Slack::Decoder
  Slack::Decoders::Stdlib.new(->(kind : Slack::Decoder::Kind, body : String) { observed << {kind, body}; nil })
end

describe Slack::App::HttpReceiver do
  it "acknowledges an event with an empty 200 and runs the matching listener" do
    app = build_app
    mentions = Channel(String).new(1)
    app.event("app_mention") do |ctx|
      event = ctx.event.should be_a(Slack::Events::AppMentioned)
      mentions.send("#{ctx.envelope.event_id} #{event.channel} retry=#{ctx.delivery.try(&.retry_num)}")
    end

    headers = HTTP::Headers{"X-Slack-Retry-Num" => "2", "X-Slack-Retry-Reason" => "http_timeout"}
    reply = receive(app, AppSupport.json(APP_MENTION, headers))

    reply.status.should eq 200
    reply.body.should be_empty
    mentions.receive.should eq "Ev-SYNTHETIC C-SYNTHETIC retry=2"
  end

  it "routes a message event whose text contains the pattern" do
    app = build_app
    texts = Channel(String?).new(1)
    app.message("release") { |_ctx| texts.send("wrong listener") }
    app.message("deploy") { |ctx| texts.send(ctx.message.text) }

    receive(app, AppSupport.json(MESSAGE)).status.should eq 200
    texts.receive.should eq "please deploy api"
  end

  it "does not route a message with an unmapped subtype to message listeners" do
    app = build_app
    routed = Channel(String).new(1)
    app.message { |_ctx| routed.send("message listener") }
    app.event("message") { |_ctx| routed.send("event listener") }

    receive(app, AppSupport.json(UNMAPPED_SUBTYPE_MESSAGE)).status.should eq 200
    routed.receive.should eq "event listener"
  end

  it "echoes a url_verification challenge without authorizing or routing" do
    app = build_app(authorizer: FailingAuthorizer.new)
    reply = receive(app, AppSupport.json(URL_VERIFICATION))

    reply.status.should eq 200
    reply.content_type.should eq "application/json"
    JSON.parse(reply.body).should eq JSON.parse(%({"challenge":"3eZbrw1aBm2rZgRNFdxV2595E9CY3gmdALWMmHkvFXO7tYXAYM8P"}))
  end

  it "returns the command response as the acknowledgment body" do
    app = build_app
    app.command("/deploy") do |ctx|
      ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}.", response_type: :in_channel))
    end

    reply = receive(app, AppSupport.form(COMMAND))

    reply.status.should eq 200
    reply.content_type.should eq "application/json"
    JSON.parse(reply.body).should eq JSON.parse(%({"response_type":"in_channel","text":"Deploying api."}))
  end

  it "routes a block action by action ID and block ID in registration order" do
    app = build_app
    calls = [] of String
    app.action("deploy.approve", "other.block") { |_ctx| calls << "wrong block" }
    app.action(/\Adeploy\./) do |ctx|
      button = ctx.action.should be_a(Slack::Interactions::ButtonAction)
      calls << "#{button.action_id}=#{button.value} in #{ctx.payload.channel.try(&.id)}"
      ctx.ack
    end
    app.action("deploy.approve") { |_ctx| calls << "later listener" }

    reply = receive(app, AppSupport.interaction(BLOCK_ACTIONS))

    reply.status.should eq 200
    reply.body.should be_empty
    calls.should eq ["deploy.approve=api in C-SYNTHETIC"]
  end

  it "returns options for a block_suggestion request" do
    app = build_app
    app.options("service.pick") do |ctx|
      option = Slack::UI::CompositionObjects::Option.new(text: Slack::UI.plain("api"), value: "svc-api")
      ctx.ack(Slack::Interactions::BlockSuggestionResponse.new(options: [option])) if ctx.payload.value == "ap"
    end

    reply = receive(app, AppSupport.interaction(BLOCK_SUGGESTION))

    reply.status.should eq 200
    JSON.parse(reply.body).should eq JSON.parse(%({"options":[{"text":{"type":"plain_text","text":"api"},"value":"svc-api"}]}))
  end

  it "returns input errors for a view submission" do
    app = build_app
    app.view("deploy.form") do |ctx|
      if ctx.payload.plain_text?("reason", "reason.text").try(&.size.< 5)
        ctx.ack(Slack::Interactions::ModalErrors.new({"reason" => "Enter at least 5 characters."}))
      end
    end

    reply = receive(app, AppSupport.interaction(VIEW_SUBMISSION))

    reply.status.should eq 200
    JSON.parse(reply.body).should eq JSON.parse(%({"response_action":"errors","errors":{"reason":"Enter at least 5 characters."}}))
  end

  it "acknowledges view_closed and a message shortcut with an empty 200" do
    app = build_app
    seen = [] of String
    app.view_closed("deploy.form") { |ctx| seen << "closed cleared=#{ctx.payload.is_cleared}" }
    app.shortcut("deploy.from_message") do |ctx|
      shortcut = ctx.shortcut.should be_a(Slack::Interactions::MessageAction)
      seen << "shortcut #{shortcut.message_ts}"
    end

    receive(app, AppSupport.interaction(VIEW_CLOSED)).status.should eq 200
    reply = receive(app, AppSupport.interaction(MESSAGE_SHORTCUT))

    reply.status.should eq 200
    reply.body.should be_empty
    seen.should eq ["closed cleared=false", "shortcut 1789232400.000100"]
  end

  it "acknowledges an unmatched payload with an empty 200 and logs its kind" do
    Log.capture("slack.app") do |logs|
      reply = receive(build_app, AppSupport.form(COMMAND))

      reply.status.should eq 200
      reply.body.should be_empty
      logs.check(:info, "No listener matched command /deploy")
    end
  end

  it "gives a decoder observer the kind and exact bytes of each verified payload" do
    app = build_app
    observed = [] of {Slack::Decoder::Kind, String}
    decoder = observing_decoder(observed)
    form = URI::Params.encode({"payload" => BLOCK_ACTIONS})

    receive(app, AppSupport.json(APP_MENTION), decoder).status.should eq 200
    receive(app, AppSupport.signed(form, "application/x-www-form-urlencoded"), decoder).status.should eq 200

    observed.should eq [{Slack::Decoder::Kind::Event, APP_MENTION}, {Slack::Decoder::Kind::Interaction, form}]
  end

  it "rejects an invalid signature before decoding or routing" do
    app = build_app
    ran = false
    app.command("/deploy") { |_ctx| ran = true }
    observed = [] of {Slack::Decoder::Kind, String}
    request = AppSupport.form(COMMAND)
    request.headers["X-Slack-Signature"] = "v0=#{"0" * 64}"

    receive(app, request, observing_decoder(observed)).status.should eq 401
    ran.should be_false
    observed.should be_empty
  end

  it "answers 401 without routing when authorization fails" do
    app = build_app(authorizer: FailingAuthorizer.new)
    ran = false
    app.command("/deploy") { |_ctx| ran = true }

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.form(COMMAND)).status.should eq 401
      logs.check(:warn, "Authorization of command /deploy failed: Slack::Auth::ContractError")
    end
    ran.should be_false
  end

  it "answers 400 for a payload that does not decode, 415 for another content type, and passes other paths on" do
    receiver = Slack::App::HttpReceiver.new(build_app, AppSupport::VERIFIER)
    secret_text = %({"type":"event_callback","token":"synthetic-leak-marker")

    Log.capture("slack.app.receiver") do |logs|
      AppSupport.run(receiver, AppSupport.json(secret_text)).status.should eq 400
      logs.check(:warn, /\ARejected a payload that does not decode: JSON::\w+\z/)
    end
    AppSupport.run(receiver, AppSupport.signed("{}", "text/plain")).status.should eq 415
    AppSupport.run(receiver, AppSupport.signed("{}", "application/json", path: "/health")).status.should eq 404
  end

  it "runs global middleware, then listener middleware, sharing the request store" do
    app = build_app
    steps = [] of String
    app.use do |ctx, call_next|
      ctx.store["actor"] = "U-SYNTHETIC"
      steps << "global"
      call_next.call
    end
    audit = Slack::App::Middleware.new do |ctx, call_next|
      steps << "listener middleware for #{ctx.store["actor"]}"
      call_next.call
    end
    app.command("/deploy", middleware: [audit]) do |ctx|
      steps << "handler for #{ctx.store["actor"]}"
      ctx.ack
    end

    receive(app, AppSupport.form(COMMAND)).status.should eq 200
    steps.should eq ["global", "listener middleware for U-SYNTHETIC", "handler for U-SYNTHETIC"]
  end

  it "acknowledges empty when middleware stops the chain" do
    app = build_app
    ran = false
    app.use { |_ctx, _call_next| nil }
    app.command("/deploy") do |ctx|
      ran = true
      ctx.ack(Slack::Commands::Response.new(text: "unreachable"))
    end

    reply = receive(app, AppSupport.form(COMMAND))

    reply.status.should eq 200
    reply.body.should be_empty
    ran.should be_false
  end

  it "answers 500 when a listener raises before it acknowledges" do
    app = build_app
    app.action("deploy.approve") { |_ctx| raise "synthetic failure" }

    Log.capture("slack.app") do |logs|
      receive(app, AppSupport.interaction(BLOCK_ACTIONS)).status.should eq 500
      # The listener fiber reports the exception after the receiver has the
      # response; a timed sleep lets the ready listener fiber run first.
      sleep 1.millisecond
      logs.check(:error, "Listener for Slack::App::ActionContext raised Exception before acknowledging")
    end
  end

  it "keeps the acknowledgment when a listener raises after it" do
    app = build_app
    done = Channel(Nil).new
    app.command("/deploy") do |ctx|
      ctx.ack(Slack::Commands::Response.new(text: "Deploying."))
      done.send(nil)
      raise "synthetic failure"
    end

    Log.capture("slack.app") do |logs|
      reply = receive(app, AppSupport.form(COMMAND))
      done.receive
      Fiber.yield

      reply.status.should eq 200
      JSON.parse(reply.body).should eq JSON.parse(%({"response_type":"ephemeral","text":"Deploying."}))
      logs.check(:error, /raised Exception after acknowledging/)
    end
  end

  it "sends one empty acknowledgment after the deadline and rejects a later ack" do
    app = build_app(ack_timeout: 20.milliseconds)
    release = Channel(Nil).new
    late_ack = Channel(Exception?).new(1)
    app.command("/deploy") do |ctx|
      release.receive
      begin
        ctx.ack(Slack::Commands::Response.new(text: "Too late."))
        late_ack.send(nil)
      rescue error
        late_ack.send(error)
      end
    end

    Log.capture("slack.app") do |logs|
      reply = receive(app, AppSupport.form(COMMAND))

      reply.status.should eq 200
      reply.body.should be_empty
      logs.check(:warn, "No acknowledgment within 20 ms; sent an empty acknowledgment")
    end
    release.send(nil)
    late_ack.receive.should be_a(Slack::App::AlreadyAcknowledged)
  end

  it "rejects a second ack from the same listener" do
    app = build_app
    second = Channel(Exception?).new(1)
    app.action("deploy.approve") do |ctx|
      ctx.ack
      begin
        ctx.ack
        second.send(nil)
      rescue error
        second.send(error)
      end
    end

    receive(app, AppSupport.interaction(BLOCK_ACTIONS)).status.should eq 200
    second.receive.should be_a(Slack::App::AlreadyAcknowledged)
  end

  it "writes the response before synchronous work that follows ack or an event acknowledgment" do
    app = build_app
    steps = [] of String
    done = Channel(Nil).new(2)
    busy = ->(label : String) do
      deadline = Time.instant + 50.milliseconds
      while Time.instant < deadline
      end
      steps << label
      done.send(nil)
    end
    app.command("/deploy") do |ctx|
      ctx.ack
      busy.call("command work finished")
    end
    app.event("app_mention") { |_ctx| busy.call("event work finished") }

    receive(app, AppSupport.form(COMMAND)).status.should eq 200
    steps << "command response written"
    done.receive
    receive(app, AppSupport.json(APP_MENTION)).status.should eq 200
    steps << "event response written"
    done.receive

    steps.should eq ["command response written", "command work finished", "event response written", "event work finished"]
  end
end
