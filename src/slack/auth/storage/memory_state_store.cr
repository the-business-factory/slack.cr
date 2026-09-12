require "../state"

module Slack::Auth
  # A synchronized, single-process reference implementation of StateStore.
  # Applications with more than one process must provide shared durable storage.
  class MemoryStateStore < StateStore
    @attempts = {} of String => AuthorizationAttempt
    @mutex = Mutex.new

    def initialize(@clock : Clock = SystemClock.new)
    end

    def issue(attempt : AuthorizationAttempt) : Nil
      @mutex.synchronize do
        key = attempt.state.value
        raise ContractError.new(ErrorCode::Conflict) if @attempts.has_key?(key)

        prune_expired_locked(@clock.now)
        @attempts[key] = attempt
      end
    end

    def consume(state : Secret, session_binding : Secret,
                purpose : AuthorizationPurpose) : AuthorizationAttempt
      @mutex.synchronize do
        attempt = @attempts[state.value]?
        unless attempt && attempt.session_binding.value == session_binding.value &&
               attempt.purpose == purpose && attempt.expires_at > @clock.now
          raise ContractError.new(ErrorCode::InvalidState)
        end

        @attempts.delete(state.value)
        attempt
      end
    end

    # Remove expired attempts when an application has no new authorization traffic.
    # Issue also prunes expired noncolliding entries; no background fiber is started.
    def prune_expired : Int32
      @mutex.synchronize { prune_expired_locked(@clock.now) }
    end

    private def prune_expired_locked(now : Time) : Int32
      before = @attempts.size
      @attempts.reject! { |_state, attempt| attempt.expires_at <= now }
      before - @attempts.size
    end
  end
end
