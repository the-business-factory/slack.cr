require "../../../src/slack/oauth/auth_handler"

module OAuthStateSupport
  class Clock < Slack::Auth::Clock
    property now : Time

    def initialize(@now : Time = Time.utc(2026, 9, 12, 12, 0, 0))
    end
  end

  class RecordingStateStore < Slack::Auth::StateStore
    getter issued = [] of Slack::Auth::AuthorizationAttempt
    @store : Slack::Auth::MemoryStateStore
    @mutex = Mutex.new

    def initialize(clock : Slack::Auth::Clock)
      @store = Slack::Auth::MemoryStateStore.new(clock)
    end

    def issue(attempt : Slack::Auth::AuthorizationAttempt) : Nil
      @store.issue(attempt)
      @mutex.synchronize { @issued << attempt }
    end

    def consume(state : Slack::Auth::Secret, session_binding : Slack::Auth::Secret,
                purpose : Slack::Auth::AuthorizationPurpose) : Slack::Auth::AuthorizationAttempt
      @store.consume(state, session_binding, purpose)
    end
  end

  class ConflictStateStore < Slack::Auth::StateStore
    getter issue_count : Int32 = 0

    def issue(attempt : Slack::Auth::AuthorizationAttempt) : Nil
      @issue_count += 1
      raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::Conflict)
    end

    def consume(state : Slack::Auth::Secret, session_binding : Slack::Auth::Secret,
                purpose : Slack::Auth::AuthorizationPurpose) : Slack::Auth::AuthorizationAttempt
      raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::InvalidState)
    end
  end

  class RecordingTransport < Slack::Auth::Transport
    @requests = [] of Slack::Auth::TransportRequest
    @responses = [] of Slack::Auth::TransportResponse
    @failure : Slack::Auth::ContractError? = nil
    @mutex = Mutex.new

    def enqueue(response : Slack::Auth::TransportResponse) : Nil
      @mutex.synchronize { @responses << response }
    end

    def fail_with(error : Slack::Auth::ContractError) : Nil
      @mutex.synchronize { @failure = error }
    end

    def requests : Array(Slack::Auth::TransportRequest)
      @mutex.synchronize { @requests.dup }
    end

    def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
      @mutex.synchronize do
        @requests << request
        if failure = @failure
          raise failure
        end
        @responses.shift? || raise Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::TransportFailure)
      end
    end
  end
end
