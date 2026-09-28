# Raised by `Slack::Testing::RecordingTransport` when a request has no response.
# The message names only the HTTP method and the URI path, so it never shows
# a token, a query, or a body.
class Slack::Testing::UnstubbedRequest < Exception
  def initialize(request : Auth::TransportRequest)
    super("No response for #{request.method} #{request.uri.path}")
  end
end
