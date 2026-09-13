require "http"
require "socket"

module AuthSupport
  class OneShotServer
    getter port : Int32

    @server : TCPServer
    @done = Channel(Exception?).new(1)

    def initialize(host : String = "127.0.0.1", &handler : TCPSocket -> Nil)
      @server = TCPServer.new(host, 0)
      @port = @server.local_address.port

      spawn(name: "auth-transport-loopback") do
        error : Exception? = nil
        client : TCPSocket? = nil
        begin
          client = @server.accept
          @server.close
          handler.call(client)
        rescue exception
          error = exception
        ensure
          client.try { |socket| socket.close unless socket.closed? }
          @server.close unless @server.closed?
          @done.send(error)
        end
      end
    end

    def wait(*, allow_error : Bool = false) : Nil
      select
      when error = @done.receive
        raise error if error && !allow_error
      when timeout(2.seconds)
        raise "Loopback fixture did not finish"
      end
    end

    def close : Nil
      @server.close unless @server.closed?
    end
  end

  def self.read_request(io : IO) : HTTP::Request
    request = HTTP::Request.from_io(io)
    return request if request.is_a?(HTTP::Request)
    raise "Expected one complete HTTP request"
  end

  def self.respond(io : IO, status : Int32, body : String,
                   headers : HTTP::Headers = HTTP::Headers.new) : Nil
    response_headers = headers.dup
    response_headers["Content-Length"] = body.bytesize.to_s
    HTTP::Client::Response.new(status, body: body, headers: response_headers).to_io(io)
    io.flush
  end
end
