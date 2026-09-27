require "webmock"

module OfflineExample
  # Routes offline example requests through WebMock.
  class WebMockTransport < Slack::Auth::Transport
    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      response = HTTP::Client.exec(request.method, request.uri,
        headers: request.headers, body: request.body)
      Slack::Auth::TransportResponse.new(response.status_code, response.headers, response.body)
    end
  end
end
