require "base64"
require "http/web_socket"
require "openssl"
require "socket"

# :nodoc:
# Opens the default Socket Mode WebSocket with a time limit on DNS, TCP
# connect, TLS, and the HTTP upgrade. `#cancel` closes a connection that is
# still in the handshake, so `Client#close` is not held by a stalled server.
#
# Failures raise `IO::Error` (including `IO::TimeoutError` and
# `Socket::Error`) or `OpenSSL::Error`. The caller owns the returned socket;
# the connector closes the TCP socket on every failure.
#
# `HTTP::WebSocket.new(uri)` has no time limits and no cancel, so this type
# does the handshake itself and builds the client-side (masked) protocol.
class Slack::SocketMode::Connector
  TIMEOUT = 10.seconds

  @mutex = Mutex.new
  @pending : TCPSocket? = nil
  @cancelled = false

  def initialize(@timeout : Time::Span = TIMEOUT)
  end

  def call(uri : URI) : HTTP::WebSocket
    host = uri.host.presence || raise Socket::Error.new("The Socket Mode URL has no host")
    tls = uri.scheme.in?("wss", "https")
    port = uri.port || (tls ? 443 : 80)
    tcp = TCPSocket.new(host, port, dns_timeout: @timeout, connect_timeout: @timeout)
    begin
      track(tcp)
      tcp.read_timeout = @timeout
      tcp.write_timeout = @timeout
      io = tls ? OpenSSL::SSL::Socket::Client.new(tcp, OpenSSL::SSL::Context::Client.new, sync_close: true, hostname: host) : tcp
      handshake(io, "#{host}:#{port}", uri.request_target)
      tcp.read_timeout = nil
      tcp.write_timeout = nil
      HTTP::WebSocket.new(HTTP::WebSocket::Protocol.new(io, masked: true))
    rescue error
      tcp.close
      raise error
    ensure
      @mutex.synchronize { @pending = nil }
    end
  end

  # Closes the handshake in progress. Later calls raise `IO::Error`.
  def cancel : Nil
    @mutex.synchronize do
      @cancelled = true
      @pending.try(&.close)
    end
  end

  private def track(tcp : TCPSocket) : Nil
    @mutex.synchronize do
      raise IO::Error.new("The Socket Mode connector is cancelled") if @cancelled
      @pending = tcp
    end
  end

  private def handshake(io : IO, host : String, target : String) : Nil
    key = Base64.strict_encode(Random::Secure.random_bytes(16))
    headers = HTTP::Headers{
      "Host"                  => host,
      "Connection"            => "Upgrade",
      "Upgrade"               => "websocket",
      "Sec-WebSocket-Version" => HTTP::WebSocket::Protocol::VERSION,
      "Sec-WebSocket-Key"     => key,
    }
    HTTP::Request.new("GET", target, headers).to_io(io)
    io.flush
    response = read_response(io)
    unless response.status.switching_protocols? &&
           response.headers["Sec-WebSocket-Accept"]? == HTTP::WebSocket::Protocol.key_challenge(key)
      raise Socket::Error.new("The WebSocket handshake was denied (HTTP #{response.status_code})")
    end
  end

  private def read_response(io : IO) : HTTP::Client::Response
    HTTP::Client::Response.from_io?(io, ignore_body: true) ||
      raise IO::EOFError.new("The server closed the connection during the WebSocket handshake")
  rescue error : IO::Error | OpenSSL::Error
    raise error
  rescue
    # The response parser raises plain exceptions for malformed input.
    raise Socket::Error.new("The WebSocket handshake response is not valid HTTP")
  end
end
