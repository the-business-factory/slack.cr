require "http/client"

module Slack::Auth
  # :nodoc:
  # Reads through interim headers without consuming body or tunnel bytes.
  # The caller owns the IO and its timeouts, including on failure.
  module HTTPResponseHeaders
    def self.read(io : IO) : HTTP::Client::Response
      loop do
        response = HTTP::Client::Response.from_io(io, ignore_body: true, decompress: false)
        # A 101 response is terminal because the connection changes protocols.
        return response unless response.status.informational? && response.status.code != 101
      end
    end
  end
end
