require "../../src/slack"
require "http/server"
require "webmock"
require "./webmock_transport"

# Runs the Socket Mode client against a local WebSocket server that stands in
# for Slack. The server sends hello and one slash command, reads the
# acknowledgment, then turns Socket Mode off.
module OfflineSocketModeClientExample
  COMMAND = %q({"envelope_id":"E-DEPLOY","type":"slash_commands","accepts_response_payload":true,"payload":{"api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","channel_id":"C-SYNTHETIC","channel_name":"general","user_id":"U-SYNTHETIC","user_name":"synthetic.user","command":"/deploy","text":"staging","response_url":"https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic","trigger_id":"1710000000.synthetic.trigger"}})

  # Returns the acknowledgment frames that the local server received.
  def self.run(output : IO = STDOUT) : Array(String)
    received = [] of String
    server = fake_slack(received)
    port = server.bind_tcp("127.0.0.1", 0).port
    spawn { server.listen }

    WebMock.allow_net_connect = false
    WebMock.stub(:post, "https://slack.com/api/apps.connections.open")
      .to_return(body: %({"ok":true,"url":"ws://127.0.0.1:#{port}/link/?ticket=synthetic"}))
    client = Slack::SocketMode::Client.new("xapp-synthetic-socket-mode",
      transport: OfflineExample::WebMockTransport.new)

    client.run do |envelope, ack|
      next ack.ack unless envelope.kind.slash_commands?
      command = Slack::Decoder.default.command(envelope.payload_json(:slash_commands), :json)
      ack.ack(Slack::Commands::Response.new(text: "Deploying #{command.text}"))
      output.puts "Acknowledged #{command.command} #{command.text}"
    end
    output.puts "Socket Mode is off; the client stopped"
    received
  ensure
    server.try(&.close)
  end

  private def self.fake_slack(received : Array(String)) : HTTP::Server
    handler = HTTP::WebSocketHandler.new do |socket, _context|
      socket.on_message do |ack|
        received << ack
        socket.send(%({"type":"disconnect","reason":"link_disabled","debug_info":{"host":"wss-synthetic.slack.com"}}))
      end
      socket.send(%({"type":"hello","num_connections":1,"connection_info":{"app_id":"A-SYNTHETIC"}}))
      socket.send(COMMAND)
    end
    HTTP::Server.new([handler] of HTTP::Handler)
  end
end
