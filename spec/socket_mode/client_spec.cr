require "../spec_helper"
require "../support/socket_mode/loopback"

private def envelope_frame(id : String, accepts_response_payload : Bool = false) : String
  %({"envelope_id":"#{id}","type":"slash_commands","accepts_response_payload":#{accepts_response_payload},) +
    %("payload":{"api_app_id":"A-SYNTHETIC","team_id":"T-SYNTHETIC","channel_id":"C-SYNTHETIC",) +
    %("channel_name":"general","user_id":"U-SYNTHETIC","user_name":"synthetic.user","command":"/deploy",) +
    %("text":"#{id}","response_url":"https://hooks.slack.com/commands/T-SYNTHETIC/1/synthetic",) +
    %("trigger_id":"1710000000.synthetic.trigger"}})
end

private def start(client : Slack::SocketMode::Client, &handler : Slack::SocketMode::Envelope, Slack::SocketMode::Acknowledger ->) : Channel(Exception?)
  finished = Channel(Exception?).new(1)
  spawn do
    client.run { |envelope, ack| handler.call(envelope, ack) }
    finished.send(nil)
  rescue error
    finished.send(error)
  end
  finished
end

# Fails every acknowledgment write the way a broken TLS connection does.
private class TlsFailingWebSocket < HTTP::WebSocket
  def send(message) : Nil
    ssl = LibSSL.ssl_new(OpenSSL::SSL::Context::Client.new)
    raise OpenSSL::SSL::Error.new(ssl, -1, "SSL_write")
  ensure
    LibSSL.ssl_free(ssl) if ssl
  end
end

# A TCP endpoint that accepts one connection, reads the handshake request,
# then runs *respond* with the peer socket.
private def raw_endpoint(&respond : TCPSocket ->) : TCPServer
  server = TCPServer.new("127.0.0.1", 0)
  spawn do
    if peer = server.accept?
      peer.gets("\r\n\r\n")
      respond.call(peer)
    end
  end
  server
end

private def ws_reply(port : Int32, ticket : String) : Slack::Auth::TransportResponse
  Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
    %({"ok":true,"url":"ws://127.0.0.1:#{port}/link/?ticket=#{ticket}"}))
end

describe Slack::SocketMode::Client do
  it "acknowledges envelopes and opens a new connection before it closes a refreshed one" do
    server = SocketModeSupport::LoopbackServer.new
    transport = SocketModeSupport::Transport.new
      .enqueue(SocketModeSupport.open_reply("one"))
      .enqueue(SocketModeSupport.open_reply("two"))
    sockets = [] of HTTP::WebSocket
    open_when_replaced = [] of Bool
    connector = server.connector(sockets)
    connect = ->(uri : URI) do
      open_when_replaced << !sockets.last.closed? unless sockets.empty?
      connector.call(uri)
    end
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport, connect: connect)

    finished = start(client) do |envelope, ack|
      ack.ack(Slack::Commands::Response.new(text: "Deploying #{envelope.command.text}")) if envelope.accepts_response_payload?
      ack.ack unless envelope.accepts_response_payload?
    end

    first = server.next_connection
    first.resource.should eq("/link/?ticket=one&app_id=A-SYNTHETIC")
    first.send(SocketModeSupport.frame("hello"))
    first.send(envelope_frame("E-ONE"))
    first.next_message.should eq(%({"envelope_id":"E-ONE"}))

    first.send(SocketModeSupport.frame("disconnect_refresh_requested"))
    second = server.next_connection
    second.resource.should eq("/link/?ticket=two&app_id=A-SYNTHETIC")
    open_when_replaced.should eq([true])
    first.wait_closed

    second.send(SocketModeSupport.frame("hello"))
    second.send(envelope_frame("E-TWO", accepts_response_payload: true))
    JSON.parse(second.next_message).should eq(JSON.parse(<<-JSON))
      {"envelope_id":"E-TWO","payload":{"response_type":"ephemeral","text":"Deploying E-TWO"}}
      JSON

    second.send(SocketModeSupport.frame("disconnect_link_disabled"))
    SocketModeSupport.receive(finished, "run to return").should be_nil
    second.wait_closed

    transport.requests.size.should eq(2)
    transport.requests.each do |request|
      request.method.should eq("POST")
      request.uri.to_s.should eq("https://slack.com/api/apps.connections.open")
      request.headers["Authorization"].should eq("Bearer xapp-synthetic")
      request.headers["Content-Type"].should eq("application/x-www-form-urlencoded")
      request.body.to_s.should be_empty
    end
  ensure
    server.try(&.close)
  end

  it "reconnects after an unexpected close and retries a failed open with backoff" do
    server = SocketModeSupport::LoopbackServer.new
    transport = SocketModeSupport::Transport.new
      .enqueue(SocketModeSupport.open_reply("one"))
      .enqueue(Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::TransportFailure))
      .enqueue(SocketModeSupport.open_reply("two"))
    delays = [] of Int32
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
      connect: server.connector([] of HTTP::WebSocket),
      reconnect_delay: ->(attempt : Int32) { delays << attempt; 1.millisecond })

    finished = start(client) { |_envelope, ack| ack.ack }

    first = server.next_connection
    first.close
    second = server.next_connection
    second.resource.should eq("/link/?ticket=two&app_id=A-SYNTHETIC")
    delays.should eq([1, 2])

    second.send(envelope_frame("E-AFTER"))
    second.next_message.should eq(%({"envelope_id":"E-AFTER"}))

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
    second.wait_closed
  ensure
    server.try(&.close)
  end

  it "keeps acknowledgments single-use and payloads limited to envelopes that accept them" do
    server = SocketModeSupport::LoopbackServer.new
    transport = SocketModeSupport::Transport.new.enqueue(SocketModeSupport.open_reply("one"))
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
      connect: server.connector([] of HTTP::WebSocket))
    errors = Channel(String).new(4)

    finished = start(client) do |envelope, ack|
      raise "handler failure" if envelope.envelope_id == "E-RAISES"
      begin
        ack.ack(Slack::Interactions::ModalClear.new)
      rescue error : Slack::SocketMode::AcknowledgmentError
        errors.send(error.message.to_s)
      end
      ack.ack
      begin
        ack.ack
      rescue error : Slack::SocketMode::AcknowledgmentError
        errors.send(error.message.to_s)
      end
    end

    connection = server.next_connection
    connection.send(envelope_frame("E-RAISES"))
    connection.send(envelope_frame("E-PLAIN"))
    connection.next_message.should eq(%({"envelope_id":"E-PLAIN"}))
    SocketModeSupport.receive(errors, "payload rejection").should contain("does not accept a response payload")
    SocketModeSupport.receive(errors, "second ack rejection").should contain("already acknowledged")

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
  ensure
    server.try(&.close)
  end

  it "lets a running handler acknowledge before run returns" do
    server = SocketModeSupport::LoopbackServer.new
    transport = SocketModeSupport::Transport.new.enqueue(SocketModeSupport.open_reply("one"))
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
      connect: server.connector([] of HTTP::WebSocket))
    started = Channel(Nil).new(1)
    release = Channel(Nil).new

    finished = start(client) do |_envelope, ack|
      started.send(nil)
      release.receive
      ack.ack
    end

    connection = server.next_connection
    connection.send(envelope_frame("E-SLOW"))
    SocketModeSupport.receive(started, "the handler to start")
    connection.send(SocketModeSupport.frame("disconnect_link_disabled"))

    select
    when finished.receive
      fail "run returned while a handler was running"
    when timeout(50.milliseconds)
    end
    release.send(nil)
    connection.next_message.should eq(%({"envelope_id":"E-SLOW"}))
    SocketModeSupport.receive(finished, "run to return").should be_nil
  ensure
    server.try(&.close)
  end

  it "backs off across repeated unexpected closes, resets after hello, and stops during the wait" do
    server = SocketModeSupport::LoopbackServer.new
    transport = SocketModeSupport::Transport.new
    3.times { |index| transport.enqueue(SocketModeSupport.open_reply("close-#{index}")) }
    delays = [] of Int32
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
      connect: server.connector([] of HTTP::WebSocket),
      reconnect_delay: ->(attempt : Int32) { delays << attempt; delays.size < 3 ? 1.millisecond : 1.hour })

    finished = start(client) { |_envelope, ack| ack.ack }

    server.next_connection.close
    server.next_connection.close
    third = server.next_connection
    third.send(SocketModeSupport.frame("hello"))
    third.close
    third.wait_closed
    select
    when finished.receive
      fail "run returned before close"
    when timeout(50.milliseconds)
    end

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
    delays.should eq([1, 2, 1])
    transport.requests.size.should eq(3)
  ensure
    server.try(&.close)
  end

  it "keeps acknowledging after a TLS write failure and still stops" do
    server = SocketModeSupport::LoopbackServer.new
    port = server.port
    transport = SocketModeSupport::Transport.new.enqueue(SocketModeSupport.open_reply("one"))
    connect = ->(uri : URI) : HTTP::WebSocket { TlsFailingWebSocket.new("127.0.0.1", uri.request_target, port) }
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport, connect: connect)
    acknowledged = Channel(String).new(2)

    finished = start(client) do |envelope, ack|
      ack.ack
      acknowledged.send(envelope.envelope_id)
    end

    connection = server.next_connection
    connection.send(envelope_frame("E-ONE"))
    SocketModeSupport.receive(acknowledged, "the first ack").should eq("E-ONE")
    connection.send(envelope_frame("E-TWO"))
    SocketModeSupport.receive(acknowledged, "the ack after a TLS failure").should eq("E-TWO")

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
  ensure
    server.try(&.close)
  end

  it "retries when the server closes the connection during the WebSocket handshake" do
    server = SocketModeSupport::LoopbackServer.new
    dropped = raw_endpoint(&.close)
    transport = SocketModeSupport::Transport.new
      .enqueue(ws_reply(dropped.local_address.port, "dropped"))
      .enqueue(ws_reply(server.port, "two"))
    delays = [] of Int32
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport,
      reconnect_delay: ->(attempt : Int32) { delays << attempt; 1.millisecond })

    finished = start(client) { |_envelope, ack| ack.ack }

    connection = server.next_connection
    connection.resource.should eq("/link/?ticket=two")
    delays.should eq([1])
    connection.send(envelope_frame("E-AFTER"))
    connection.next_message.should eq(%({"envelope_id":"E-AFTER"}))

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
  ensure
    server.try(&.close)
    dropped.try(&.close)
  end

  it "closes a stalled WebSocket handshake when the client stops" do
    requested = Channel(Nil).new(1)
    released = Channel(Nil).new(1)
    stalled = raw_endpoint do |peer|
      requested.send(nil)
      peer.read_byte
      released.send(nil)
    end
    transport = SocketModeSupport::Transport.new.enqueue(ws_reply(stalled.local_address.port, "stalled"))
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport)

    finished = start(client) { |_envelope, ack| ack.ack }
    SocketModeSupport.receive(requested, "the handshake request")

    client.close
    SocketModeSupport.receive(finished, "run to return").should be_nil
    SocketModeSupport.receive(released, "the client to close the handshake")
  ensure
    stalled.try(&.close)
  end

  it "raises a Slack error from apps.connections.open without connecting" do
    transport = SocketModeSupport::Transport.new.enqueue(
      Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":false,"error":"invalid_auth"})))
    connect = ->(_uri : URI) : HTTP::WebSocket { raise "must not connect" }
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: transport, connect: connect)

    finished = start(client) { |_envelope, ack| ack.ack }

    error = SocketModeSupport.receive(finished, "run to fail").should be_a(Slack::Api::Error)
    error.code.should eq("invalid_auth")
  end

  it "redacts the app token" do
    client = Slack::SocketMode::Client.new("xapp-synthetic", transport: SocketModeSupport::Transport.new)

    client.inspect.should_not contain("xapp-synthetic")
  end
end
