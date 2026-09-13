require "webmock"

module AuthSupport
  # Keeps endpoint model specs behind WebMock while production transport uses real sockets.
  class WebMockTransport < Slack::Auth::Transport
    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      response = HTTP::Client.exec(request.method, request.uri,
        headers: request.headers, body: request.body)
      Slack::Auth::TransportResponse.new(response.status_code, response.headers, response.body)
    end
  end
end
