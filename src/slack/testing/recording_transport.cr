require "http/headers"
require "../auth/transport"
require "./unstubbed_request"

# An offline `Auth::Transport` that records every request and answers with
# responses that the test supplies. It never opens a connection.
#
# Queued responses are used first, in order. When the queue is empty, the
# block given to `new` answers. Without a block, the transport raises
# `UnstubbedRequest`. The transport records the request before it answers or
# raises.
#
# ```
# transport = Slack::Testing::RecordingTransport.new
# transport.respond(%({"ok":true}))
# client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport)
# client.call(Slack::Api::ReactionsAdd.new(channel: "C123", name: "eyes", timestamp: "1710000000.000100"))
# transport.requests.first.body # => %({"channel":"C123","name":"eyes","timestamp":"1710000000.000100"})
# ```
#
# Recorded requests contain credentials. Use synthetic tokens in tests.
class Slack::Testing::RecordingTransport < Slack::Auth::Transport
  alias Responder = Auth::TransportRequest -> Auth::TransportResponse

  @responses = Deque(Auth::TransportResponse).new
  @requests = [] of Auth::TransportRequest
  @mutex = Mutex.new

  def initialize(@responder : Responder? = nil)
  end

  def self.new(&responder : Auth::TransportRequest -> Auth::TransportResponse) : self
    new(responder)
  end

  # Adds a response to the end of the queue.
  def respond(body : String, *, status : Int32 = 200, headers : HTTP::Headers = HTTP::Headers.new) : self
    @mutex.synchronize { @responses << Auth::TransportResponse.new(status, headers.dup, body) }
    self
  end

  # Returns a copy of the requests in the order the transport received them.
  def requests : Array(Auth::TransportRequest)
    @mutex.synchronize { @requests.dup }
  end

  def execute(request : Auth::TransportRequest) : Auth::TransportResponse
    queued = @mutex.synchronize do
      @requests << request
      @responses.shift?
    end
    return queued if queued
    responder = @responder || raise UnstubbedRequest.new(request)
    responder.call(request)
  end
end
