require "../../src/slack"
require "http/server"
require "webmock"
require "./webmock_transport"

# Runs `Slack::App` listeners over Socket Mode with
# `Slack::App::SocketModeReceiver`. A local WebSocket server stands in for
# Slack: it sends hello, a slash command, and a view submission, reads both
# acknowledgments, then turns Socket Mode off.
module OfflineSocketModeAppExample
  # Independently authored from the Socket Mode, slash command, and
  # view_submission references.
  COMMAND = %q({"envelope_id":"E-DEPLOY","type":"slash_commands","accepts_response_payload":true,"payload":{"token":"synthetic-legacy-token","api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","channel_id":"C-DEPLOYS","channel_name":"deploys","user_id":"U-SYNTHETIC","user_name":"synthetic.user","command":"/deploy","text":"api","response_url":"https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic","trigger_id":"1789232400.synthetic.trigger"}})
  SUBMIT  = %q({"envelope_id":"E-SUBMIT","type":"interactive","accepts_response_payload":true,"payload":{"type":"view_submission","api_app_id":"A-SYNTHETIC","team":{"id":"T-SYNTHETIC","domain":"synthetic"},"user":{"id":"U-SYNTHETIC","team_id":"T-SYNTHETIC"},"trigger_id":"1789232401.synthetic.trigger","view":{"id":"V-DEPLOY","type":"modal","callback_id":"deploy.form","team_id":"T-SYNTHETIC","state":{"values":{"reason":{"reason.text":{"type":"plain_text_input","value":"ok"}}}}},"response_urls":[]}})

  def self.build_app : Slack::App
    client = Slack::Api::Client.new(token: Slack::Auth::Secret.new("xoxb-synthetic-app"),
      transport: OfflineExample::WebMockTransport.new)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))

    app.command("/deploy") do |ctx|
      ctx.ack(Slack::Commands::Response.new(text: "Deploying #{ctx.command.text}."))
    end

    app.view("deploy.form") do |ctx|
      ctx.ack(Slack::Interactions::ModalErrors.new({"reason" => "Enter at least 5 characters."}))
    end
    app
  end

  # Returns the acknowledgment frames that the local server received.
  def self.run(output : IO = STDOUT) : Array(String)
    received = [] of String
    server = fake_slack(received)
    port = server.bind_tcp("127.0.0.1", 0).port
    spawn { server.listen }

    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/apps.connections.open")
      .to_return(body: %({"ok":true,"url":"ws://127.0.0.1:#{port}/link/?ticket=synthetic"}))
    # In an application: Slack::SocketMode::Client.new(Slack::Auth::Secret.new(ENV["SLACK_APP_TOKEN"]))
    socket = Slack::SocketMode::Client.new("xapp-synthetic-socket-mode", transport: OfflineExample::WebMockTransport.new)

    Slack::App::SocketModeReceiver.new(build_app, socket).run
    output.puts "Acknowledged #{received.size} envelopes; Socket Mode is off"
    received
  ensure
    server.try(&.close)
  end

  private def self.fake_slack(received : Array(String)) : HTTP::Server
    handler = HTTP::WebSocketHandler.new do |socket, _context|
      socket.on_message do |ack|
        received << ack
        next socket.send(SUBMIT) if received.size == 1
        socket.send(%({"type":"disconnect","reason":"link_disabled","debug_info":{"host":"wss-synthetic.slack.com"}}))
      end
      socket.send(%({"type":"hello","num_connections":1,"connection_info":{"app_id":"A-SYNTHETIC"}}))
      socket.send(COMMAND)
    end
    HTTP::Server.new([handler] of HTTP::Handler)
  end
end
