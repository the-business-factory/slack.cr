require "../spec_helper"
require "../support/api/webmock_client"
require "../support/socket_mode/loopback"

# Envelopes and payloads below are authored independently from the Slack references:
# https://docs.slack.dev/apis/events-api/using-socket-mode
# https://docs.slack.dev/reference/events/app_mention
# https://docs.slack.dev/interactivity/implementing-slash-commands
# https://docs.slack.dev/reference/interaction-payloads/block_actions-payload
# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload
private def app_mention_envelope(id : String, retry_attempt : Int32, retry_reason : String) : String
  <<-JSON
    {"envelope_id":"#{id}","type":"events_api","accepts_response_payload":false,
     "retry_attempt":#{retry_attempt},"retry_reason":"#{retry_reason}",
     "payload":{"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
       "event":{"type":"app_mention","user":"U-SYNTHETIC","text":"<@U-BOT> deploy","ts":"1789232400.000100",
                "channel":"C-SYNTHETIC","event_ts":"1789232400.000100"},
       "type":"event_callback","event_id":"Ev-#{id}","event_time":1789232400,
       "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}}
    JSON
end

private def command_envelope(id : String, accepts_response_payload : Bool = true) : String
  <<-JSON
    {"envelope_id":"#{id}","type":"slash_commands","accepts_response_payload":#{accepts_response_payload},
     "payload":{"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","team_domain":"synthetic",
       "channel_id":"C-SYNTHETIC","channel_name":"deploys","user_id":"U-SYNTHETIC","user_name":"synthetic.user",
       "command":"/deploy","text":"api","api_app_id":"A-SYNTHETIC",
       "response_url":"https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",
       "trigger_id":"1789232400.synthetic.trigger"}}
    JSON
end

private def block_actions_envelope(id : String) : String
  <<-JSON
    {"envelope_id":"#{id}","type":"interactive","accepts_response_payload":false,
     "payload":{"type":"block_actions","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
       "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
       "container":{"type":"message","message_ts":"1789232400.000100","channel_id":"C-SYNTHETIC","is_ephemeral":false},
       "channel":{"id":"C-SYNTHETIC","name":"deploys"},
       "actions":[{"type":"button","action_id":"deploy.approve","block_id":"deploy.actions",
                   "text":{"type":"plain_text","text":"Approve"},"value":"api","action_ts":"1789232401.000001"}]}}
    JSON
end

private VIEW_SUBMISSION_ENVELOPE = <<-JSON
  {"envelope_id":"E-VIEW","type":"interactive","accepts_response_payload":true,
   "payload":{"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},
     "user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"trigger_id":"1789232400.synthetic.trigger",
     "view":{"id":"V-SYNTHETIC","type":"modal","callback_id":"deploy.form","team_id":"T-SYNTHETIC",
             "state":{"values":{"reason":{"reason.text":{"type":"plain_text_input","value":"x"}}}}},
     "response_urls":[]}}
  JSON

private class RejectingAuthorizer < Slack::App::Authorizer
  def authorize(payload : Slack::App::Payload) : Slack::Api::Client
    raise Slack::Auth::ContractError.new(:missing_installation)
  end

  def authorize(payload : Slack::App::Payload, grant : Slack::Auth::GrantKey) : Slack::Api::Client
    raise Slack::Auth::ContractError.new(:missing_installation)
  end
end

# A receiver on a Socket Mode client that is connected to a loopback server.
private record Harness,
  server : SocketModeSupport::LoopbackServer,
  connection : SocketModeSupport::Connection,
  receiver : Slack::App::SocketModeReceiver,
  finished : Channel(Exception?) do
  def send(frame : String) : Nil
    connection.send(frame)
  end

  def next_ack : JSON::Any
    JSON.parse(connection.next_message)
  end

  # Closes the receiver and waits for `run` to return.
  def stop : Exception?
    receiver.close
    SocketModeSupport.receive(finished, "run to return")
  ensure
    server.close
  end
end

# Collects the receiver's warnings while the block runs.
private def capture_warnings(& : Array(Log::Entry) ->) : Nil
  backend = Log::MemoryBackend.new
  Log.builder.bind("slack.app.socket_mode_receiver", :warn, backend)
  yield backend.entries
ensure
  Log.builder.unbind("slack.app.socket_mode_receiver", :warn, backend) if backend
end

# Waits until a warning that names *envelope_id* is logged. Envelopes run on
# separate fibers, so their log order is not fixed.
private def wait_for_warning(warnings : Array(Log::Entry), envelope_id : String) : Nil
  deadline = Time.instant + SocketModeSupport::WAIT
  until warnings.any?(&.message.includes?(envelope_id))
    raise "Timed out waiting for a warning about #{envelope_id}" if Time.instant >= deadline
    sleep 1.millisecond
  end
end

private def build_app(authorizer : Slack::App::Authorizer? = nil) : Slack::App
  Slack::App.new(authorizer: authorizer || Slack::App::SingleTokenAuthorizer.new(ApiSupport.client))
end

private def connect(app : Slack::App, decoder : Slack::Decoder = Slack::Decoder.default) : Harness
  server = SocketModeSupport::LoopbackServer.new
  transport = SocketModeSupport::Transport.new.enqueue(SocketModeSupport.open_reply("one"))
  client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
    connect: server.connector([] of HTTP::WebSocket))
  receiver = Slack::App::SocketModeReceiver.new(app, client, decoder: decoder)
  finished = Channel(Exception?).new(1)
  spawn do
    receiver.run
    finished.send(nil)
  rescue error
    finished.send(error)
  end
  connection = server.next_connection
  connection.send(SocketModeSupport.frame("hello"))
  Harness.new(server, connection, receiver, finished)
end

describe Slack::App::SocketModeReceiver do
  it "acknowledges a slash command with the listener's response and returns from run after close" do
    app = build_app
    app.command("/deploy") do |ctx|
      ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}"))
    end
    harness = connect(app)

    harness.send(command_envelope("E-COMMAND"))

    harness.next_ack.should eq JSON.parse(<<-JSON)
      {"envelope_id":"E-COMMAND","payload":{"response_type":"ephemeral","text":"Deploying api"}}
      JSON
    harness.stop.should be_nil
  end

  it "acknowledges an event before its listener runs and exposes the retry fields as the delivery" do
    app = build_app
    release = Channel(Nil).new
    deliveries = Channel(String).new(2)
    app.on_app_mention do |ctx|
      release.receive
      delivery = ctx.delivery.should_not be_nil
      deliveries.send("#{ctx.envelope.event_id} retry=#{delivery.retry?} #{delivery.retry_num} #{delivery.retry_reason}")
    end
    harness = connect(app)

    harness.send(app_mention_envelope("E-RETRY", retry_attempt: 2, retry_reason: "timeout"))
    harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-RETRY"}))
    release.send(nil)
    SocketModeSupport.receive(deliveries, "the retried event").should eq "Ev-E-RETRY retry=true 2 timeout"

    harness.send(app_mention_envelope("E-FIRST", retry_attempt: 0, retry_reason: ""))
    harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-FIRST"}))
    release.send(nil)
    SocketModeSupport.receive(deliveries, "the first delivery").should eq "Ev-E-FIRST retry=false  "
  ensure
    harness.try(&.stop)
  end

  it "gives a decoder observer the kind and payload of an envelope before it decodes the payload" do
    observed = Channel({Slack::Decoder::Kind, String}).new(1)
    decoder = Slack::Decoders::Stdlib.new(->(kind : Slack::Decoder::Kind, body : String) { observed.send({kind, body}) })
    harness = connect(build_app, decoder)

    harness.send(command_envelope("E-OBSERVED"))

    kind, body = SocketModeSupport.receive(observed, "the observed payload")
    kind.should eq Slack::Decoder::Kind::Command
    JSON.parse(body).should eq JSON.parse(command_envelope("E-OBSERVED"))["payload"]
    harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-OBSERVED"}))
  ensure
    harness.try(&.stop)
  end

  it "routes an event through an injected standard library decoder" do
    app = build_app
    mentions = Channel(String).new(1)
    app.on_app_mention { |ctx| mentions.send(ctx.event.text) }
    harness = connect(app, Slack::Decoders::Stdlib.new)

    harness.send(app_mention_envelope("E-STDLIB", retry_attempt: 0, retry_reason: ""))

    harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-STDLIB"}))
    SocketModeSupport.receive(mentions, "the mention").should eq "<@U-BOT> deploy"
  ensure
    harness.try(&.stop)
  end

  it "acknowledges a view submission with a response action" do
    app = build_app
    app.view("deploy.form") do |ctx|
      ctx.ack(Slack::Interactions::ModalErrors.new({"reason" => "Enter at least 5 characters."}))
    end
    harness = connect(app)

    harness.send(VIEW_SUBMISSION_ENVELOPE)

    harness.next_ack.should eq JSON.parse(<<-JSON)
      {"envelope_id":"E-VIEW","payload":{"response_action":"errors","errors":{"reason":"Enter at least 5 characters."}}}
      JSON

  ensure
    harness.try(&.stop)
  end

  it "sends an empty acknowledgment when a listener returns without acknowledging" do
    app = build_app
    clicks = Channel(String).new(1)
    app.action("deploy.approve") { |ctx| clicks.send(ctx.action.should(be_a(Slack::Interactions::ButtonAction)).value.to_s) }
    harness = connect(app)

    harness.send(block_actions_envelope("E-CLICK"))

    harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-CLICK"}))
    SocketModeSupport.receive(clicks, "the click listener").should eq "api"
  ensure
    harness.try(&.stop)
  end

  it "leaves an envelope unacknowledged when the listener raises before acknowledging or the payload does not decode" do
    app = build_app
    app.action("deploy.approve") { |_ctx| raise "synthetic listener failure" }
    app.command("/deploy", &.ack)
    harness = connect(app)

    capture_warnings do |warnings|
      harness.send(block_actions_envelope("E-RAISES"))
      harness.send(%({"envelope_id":"E-BROKEN","type":"slash_commands","accepts_response_payload":true,"payload":{"command":"/deploy"}}))
      wait_for_warning(warnings, "E-RAISES")
      wait_for_warning(warnings, "E-BROKEN")
      harness.send(command_envelope("E-AFTER"))

      harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-AFTER"}))
    end
  ensure
    harness.try(&.stop)
  end

  it "leaves an envelope unacknowledged when authorization fails" do
    app = build_app(RejectingAuthorizer.new)
    app.command("/deploy") { |_ctx| raise "the listener must not run" }
    harness = connect(app)

    capture_warnings do |warnings|
      harness.send(command_envelope("E-DENIED"))
      wait_for_warning(warnings, "E-DENIED")
      harness.send(%({"envelope_id":"E-NEW-KIND","type":"future_kind","payload":{}}))

      harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-NEW-KIND"}))
    end
  ensure
    harness.try(&.stop)
  end

  it "drops a response body that the envelope does not accept and sends a plain acknowledgment" do
    app = build_app
    app.command("/deploy") { |ctx| ctx.ack(Slack::Commands::Response.new(text: "Deploying")) }
    harness = connect(app)

    capture_warnings do |warnings|
      harness.send(command_envelope("E-NO-PAYLOAD", accepts_response_payload: false))

      harness.next_ack.should eq JSON.parse(%({"envelope_id":"E-NO-PAYLOAD"}))
      wait_for_warning(warnings, "E-NO-PAYLOAD")
    end
  ensure
    harness.try(&.stop)
  end
end
