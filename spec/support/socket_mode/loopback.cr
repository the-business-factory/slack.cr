require "http/server"
require "http/web_socket"

module SocketModeSupport
  WAIT = 5.seconds

  def self.frame(name : String) : String
    File.read(File.join(__DIR__, "../../fixtures/socket_mode", "#{name}.json"))
  end

  # Receives from *channel*, or fails the example after `WAIT`.
  def self.receive(channel : Channel(T), what : String) : T forall T
    select
    when value = channel.receive
      value
    when timeout(WAIT)
      raise "Timed out waiting for #{what}"
    end
  end

  # A `connections.open` reply that points at *ticket*.
  def self.open_reply(ticket : String) : Slack::Auth::TransportResponse
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      %({"ok":true,"url":"wss://wss-primary.slack.com/link/?ticket=#{ticket}&app_id=A-SYNTHETIC"}))
  end

  # Replies to `apps.connections.open` in order. A queued `ContractError` is raised.
  class Transport < Slack::Auth::Transport
    @replies = [] of Slack::Auth::TransportResponse | Slack::Auth::ContractError
    @requests = [] of Slack::Auth::TransportRequest
    @mutex = Mutex.new

    def enqueue(reply : Slack::Auth::TransportResponse | Slack::Auth::ContractError) : self
      @mutex.synchronize { @replies << reply }
      self
    end

    def requests : Array(Slack::Auth::TransportRequest)
      @mutex.synchronize { @requests.dup }
    end

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      reply = @mutex.synchronize do
        @requests << request
        @replies.shift? || Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::TransportFailure)
      end
      raise reply if reply.is_a?(Slack::Auth::ContractError)
      reply
    end
  end

  # The server side of one accepted WebSocket connection.
  class Connection
    getter resource : String
    getter messages = Channel(String).new(16)
    getter closed = Channel(Nil).new

    def initialize(@socket : HTTP::WebSocket, @resource : String)
      @socket.on_message { |text| @messages.send(text) }
      @socket.on_close { |_code, _message| @closed.close }
    end

    def send(text : String) : Nil
      @socket.send(text)
    end

    def close : Nil
      @socket.close
    end

    def next_message : String
      SocketModeSupport.receive(@messages, "a client frame")
    end

    def wait_closed : Nil
      select
      when @closed.receive?
      when timeout(WAIT)
        raise "Timed out waiting for the client to close #{@resource}"
      end
    end
  end

  # An in-process WebSocket server on 127.0.0.1 that stands in for Slack.
  class LoopbackServer
    getter port : Int32
    @connections = Channel(Connection).new(8)

    def initialize
      handler = HTTP::WebSocketHandler.new do |socket, context|
        @connections.send(Connection.new(socket, context.request.resource))
      end
      @server = HTTP::Server.new([handler] of HTTP::Handler)
      @port = @server.bind_tcp("127.0.0.1", 0).port
      spawn { @server.listen }
    end

    def next_connection : Connection
      SocketModeSupport.receive(@connections, "a client connection")
    end

    # A `connect` proc that sends Slack's URL path and query to this server.
    # It records each client socket so specs can check which ones are open.
    def connector(sockets : Array(HTTP::WebSocket)) : Proc(URI, HTTP::WebSocket)
      port = @port
      ->(uri : URI) do
        socket = HTTP::WebSocket.new("127.0.0.1", uri.request_target, port)
        sockets << socket
        socket
      end
    end

    def close : Nil
      @server.close
    end
  end
end
