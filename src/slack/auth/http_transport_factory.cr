require "./http_transport"

module Slack::Auth
  class HTTPTransportFactory < TransportFactory
    def build(options : TransportOptions) : Transport
      HTTPTransport.new(options)
    end
  end
end
