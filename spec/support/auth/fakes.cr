require "../../../src/slack/auth/contracts"

module AuthSupport
  class FakeClock < Slack::Auth::Clock
    property now : Time

    def initialize(@now = Time.utc(2026, 1, 1))
    end
  end

  class StateStore < Slack::Auth::StateStore
    @attempts = {} of String => Slack::Auth::AuthorizationAttempt
    @mutex = Mutex.new

    def initialize(@clock : Slack::Auth::Clock)
    end

    def issue(attempt : Slack::Auth::AuthorizationAttempt) : Nil
      @mutex.synchronize do
        raise Slack::Auth::ContractError.new(:conflict) if @attempts.has_key?(attempt.state.value)
        @attempts[attempt.state.value] = attempt
      end
    end

    def consume(state : Slack::Auth::Secret, session_binding : Slack::Auth::Secret,
                purpose : Slack::Auth::AuthorizationPurpose) : Slack::Auth::AuthorizationAttempt
      @mutex.synchronize do
        attempt = @attempts[state.value]?
        unless attempt && attempt.session_binding.value == session_binding.value &&
               attempt.purpose == purpose && attempt.expires_at > @clock.now
          raise Slack::Auth::ContractError.new(:invalid_state)
        end
        @attempts.delete(state.value)
        attempt
      end
    end
  end

  class RecordingTransport < Slack::Auth::Transport
    getter requests = [] of Slack::Auth::TransportRequest
    @responses = [] of Slack::Auth::TransportResponse

    def enqueue(response : Slack::Auth::TransportResponse) : Nil
      @responses << response
    end

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      @requests << request
      @responses.shift? || raise Slack::Auth::ContractError.new(:transport_failure)
    end
  end
end
