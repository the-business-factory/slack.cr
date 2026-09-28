require "http/web_socket"
require "log"
require "openssl"
require "wait_group"

module Slack::SocketMode
  # Receives envelopes over one Socket Mode WebSocket connection and sends
  # their acknowledgments.
  #
  # ```
  # client = Slack::SocketMode::Client.new(ENV["SLACK_APP_TOKEN"])
  # client.run do |envelope, ack|
  #   ack.ack
  #   puts envelope.kind
  # end
  # ```
  #
  # For each connection, the client calls `apps.connections.open` with the
  # app-level token and connects to the returned URL. Slack allows up to 10
  # connections for an app; this client keeps one.
  #
  # Connection changes:
  #
  # - `Disconnect` with `warning`, `refresh_requested`, or an unknown reason:
  #   the client opens a new connection, then closes the old one.
  # - `Disconnect` with `link_disabled`: `#run` stops and returns.
  # - A close without a `Disconnect` frame: the client waits, then opens a new
  #   connection.
  #
  # When an open fails with a transport error, a network or TLS error
  # (`IO::Error`, `OpenSSL::Error`), or `Api::RateLimited`, the client waits
  # and tries again. Failed opens and unexpected closes count as failures
  # until a connection receives `hello`. The wait after failure *n* is
  # `reconnect_delay.call(n)` (default 1, 2, 4, … seconds, at most 30), or the
  # `Retry-After` time of a rate limit. `#close` interrupts the wait. Any other
  # `Api::Error`, such as `invalid_auth`, stops `#run` and raises.
  #
  # The default connector limits DNS, TCP connect, TLS, and the WebSocket
  # handshake to 10 seconds each, and `#close` closes a handshake in progress.
  # A replacement *connect* proc must raise `IO::Error` or `OpenSSL::Error`
  # for failures that the client should retry.
  #
  # ## Fibers
  #
  # - The fiber that calls `#run` opens connections and follows connection
  #   changes. It is the only fiber that replaces the current socket.
  # - One reader fiber per connection reads frames. It starts one handler fiber
  #   for each envelope and reports disconnects and closes to the `#run` fiber
  #   through a channel. `HTTP::WebSocket` answers ping frames in this fiber.
  # - One writer fiber sends all acknowledgments on the current connection, so
  #   acknowledgment frames never interleave. An acknowledgment for an envelope
  #   from a replaced connection goes out on the new connection.
  #
  # A `Mutex` protects the current socket reference, the stop flag, and the
  # failure count. When
  # `#run` stops, it starts no more handlers, waits for the running handlers,
  # sends their queued acknowledgments, then closes the connection and the
  # channels. A handler that never returns keeps `#run` from returning.
  #
  # A handler exception is logged by class name and the envelope stays
  # unacknowledged, so Slack can deliver it again. Malformed frames are logged
  # by error class and ignored.
  class Client
    Log = ::Log.for("slack.socket_mode")

    MAX_RECONNECT_DELAY = 30.seconds

    # :nodoc:
    record Closed, socket : HTTP::WebSocket

    # :nodoc:
    record Disconnected, socket : HTTP::WebSocket, frame : Disconnect

    alias Handler = Proc(Envelope, Acknowledger, Nil)

    @api : Api::Client
    @socket : HTTP::WebSocket? = nil
    @mutex = Mutex.new
    @started = false
    @stopping = false
    @failures = 0
    @connector = Connector.new
    @handlers = WaitGroup.new
    @stop = Channel(Nil).new
    @changes = Channel(Closed | Disconnected).new
    @outbox = Channel(Acknowledgment).new
    @writer_done = Channel(Nil).new

    # *app_token* is an app-level token (`xapp-`). *configuration* and
    # *transport* are used for `apps.connections.open`. *connect* opens the
    # WebSocket for a URL instead of the default connector; specs use it to
    # reach a local server.
    def initialize(app_token : String | Auth::Secret, *,
                   configuration : Auth::APIConfiguration = Auth::APIConfiguration.default,
                   transport : Auth::Transport = Auth::HTTPTransportFactory.new.build(Auth::TransportOptions.new),
                   @connect : Proc(URI, HTTP::WebSocket)? = nil,
                   @reconnect_delay : Proc(Int32, Time::Span) = ->(attempt : Int32) { Client.reconnect_delay(attempt) })
      @api = Api::Client.new(token: app_token, configuration: configuration, transport: transport)
    end

    # The default wait before open attempt *attempt* (1, 2, 4, … seconds, at most 30).
    def self.reconnect_delay(attempt : Int32) : Time::Span
      Math.min(2.0 ** (attempt - 1), MAX_RECONNECT_DELAY.total_seconds).seconds
    end

    # Receives envelopes until `#close` or a `link_disabled` disconnect, then
    # returns after every handler has finished. Calls *handler* on a new fiber
    # for each envelope. A client runs once.
    def run(&handler : Envelope, Acknowledger ->) : Nil
      start
      spawn_writer
      begin
        supervise(handler) if connect(handler)
      ensure
        shut_down
      end
    end

    # Asks `#run` to stop and closes a default-connector handshake in progress.
    # It does not wait for `#run` to return.
    def close : Nil
      @stop.close
      @connector.cancel
    end

    def inspect(io : IO) : Nil
      io << "#<Slack::SocketMode::Client app_token=[REDACTED]>"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end

    private def start : Nil
      @mutex.synchronize do
        raise ArgumentError.new("A Socket Mode client runs only once") if @started
        @started = true
      end
    end

    private def supervise(handler : Handler) : Nil
      loop do
        select
        when @stop.receive?
          return
        when change = @changes.receive
          return unless follow(change, handler)
        end
      end
    end

    # Returns false when the client must stop.
    private def follow(change : Closed | Disconnected, handler : Handler) : Bool
      return true unless current?(change.socket)
      case change
      in Disconnected
        return false if change.frame.reason.link_disabled?
      in Closed
        return false unless pause(@reconnect_delay.call(record_failure))
      end
      connect(handler)
    end

    # Opens a connection, makes it current, then closes the previous one.
    # Returns false when `#close` interrupts the attempts.
    private def connect(handler : Handler) : Bool
      socket = open_with_backoff(handler)
      return false unless socket
      previous = @mutex.synchronize do
        replaced = @socket
        @socket = socket
        replaced
      end
      close_socket(previous) if previous
      true
    end

    private def open_with_backoff(handler : Handler) : HTTP::WebSocket?
      loop do
        return if @stop.closed?
        begin
          return open_socket(handler)
        rescue error : Api::RateLimited | Auth::ContractError | IO::Error | OpenSSL::Error
          raise error unless retryable?(error)
          attempt = record_failure
          Log.warn { "Socket Mode connection attempt #{attempt} failed (#{error.class}); retrying" }
          return unless pause(retry_delay(error, attempt))
        end
      end
    end

    # Counts a failed open or an unexpected close. A `hello` resets the count.
    private def record_failure : Int32
      @mutex.synchronize { @failures += 1 }
    end

    private def retryable?(error : Exception) : Bool
      return true unless error.is_a?(Auth::ContractError)
      error.code.transport_failure? || error.code.unknown_remote_outcome?
    end

    private def retry_delay(error : Exception, attempt : Int32) : Time::Span
      retry_after = error.retry_after if error.is_a?(Api::RateLimited)
      retry_after || @reconnect_delay.call(attempt)
    end

    # Returns false when `#close` interrupts the wait.
    private def pause(delay : Time::Span) : Bool
      select
      when @stop.receive?
        false
      when timeout(delay)
        true
      end
    end

    private def open_socket(handler : Handler) : HTTP::WebSocket
      url = @api.call(Api::AppsConnectionsOpen.new).url
      connect = @connect
      socket = connect ? connect.call(url) : @connector.call(url)
      socket.on_message { |text| receive(socket, text, handler) }
      spawn(name: "slack.socket_mode.reader") { read(socket) }
      socket
    end

    private def read(socket : HTTP::WebSocket) : Nil
      socket.run
    rescue error : IO::Error | OpenSSL::Error
      # A pong write failed; the connection is gone.
      Log.debug { "Socket Mode connection ended (#{error.class})" }
    ensure
      report(Closed.new(socket))
    end

    private def receive(socket : HTTP::WebSocket, text : String, handler : Handler) : Nil
      case frame = Frame.parse(text)
      in Envelope     then dispatch(frame, handler)
      in Disconnect   then report(Disconnected.new(socket, frame))
      in Hello        then ready(frame)
      in UnknownFrame then Log.debug { "Ignored a Socket Mode #{frame.type.inspect} frame" }
      end
    rescue error : JSON::ParseException | Interactions::TypeMismatch
      Log.warn { "Ignored a malformed Socket Mode frame (#{error.class})" }
    end

    private def ready(hello : Hello) : Nil
      @mutex.synchronize { @failures = 0 }
      Log.debug { "Socket Mode connection ready (#{hello.num_connections} open)" }
    end

    private def dispatch(envelope : Envelope, handler : Handler) : Nil
      acknowledger = Acknowledger.new(envelope, @outbox)
      @mutex.synchronize do
        return if @stopping
        @handlers.add
      end
      spawn(name: "slack.socket_mode.handler") do
        handler.call(envelope, acknowledger)
      rescue error
        Log.error { "Socket Mode handler raised #{error.class} for envelope #{envelope.envelope_id}" }
      ensure
        @handlers.done
      end
    end

    # A reader can report after `#run` has stopped; the change is dropped.
    private def report(change : Closed | Disconnected) : Nil
      @changes.send(change)
    rescue Channel::ClosedError
    end

    private def spawn_writer : Nil
      spawn(name: "slack.socket_mode.writer") do
        while acknowledgment = @outbox.receive?
          write(acknowledgment)
        end
      ensure
        @writer_done.close
      end
    end

    private def write(acknowledgment : Acknowledgment) : Nil
      socket = @mutex.synchronize { @socket }
      raise IO::Error.new("No open connection") unless socket
      socket.send(acknowledgment.to_json)
    rescue error : IO::Error | OpenSSL::Error
      Log.warn { "Could not acknowledge envelope #{acknowledgment.envelope_id} (#{error.class})" }
    end

    private def current?(socket : HTTP::WebSocket) : Bool
      @mutex.synchronize { @socket.same?(socket) }
    end

    private def shut_down : Nil
      @mutex.synchronize { @stopping = true }
      @handlers.wait
      @outbox.close
      @writer_done.receive?
      socket = @mutex.synchronize do
        last = @socket
        @socket = nil
        last
      end
      close_socket(socket) if socket
      @changes.close
      @stop.close
    end

    private def close_socket(socket : HTTP::WebSocket) : Nil
      socket.close
    rescue IO::Error | OpenSSL::Error
      # The peer already dropped the connection.
    end
  end
end
