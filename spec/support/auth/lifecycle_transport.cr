require "./oauth_state_fakes"

module LifecycleSupport
  # Runs a deterministic store mutation after Slack accepts the request and before
  # its response reaches the rotation service. No background fiber needs cleanup.
  class Transport < OAuthStateSupport::RecordingTransport
    property before_response : Proc(Nil)? = nil

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      response = super(request)
      @before_response.try(&.call)
      response
    end
  end
end
