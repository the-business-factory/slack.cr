require "../auth/errors"
require "./rate_limited"

module Slack::Api
  # Decides when `Client` sends a failed request again. Give it to `Client.new(retry:)`.
  #
  # ```
  # policy = Slack::Api::RetryPolicy.new(max_attempts: 3, max_wait: 30.seconds)
  # client = Slack::Api::Client.new(token: ENV["SLACK_BOT_TOKEN"], retry: policy)
  # ```
  #
  # The client sends a request again only in two cases:
  #
  # - HTTP 429 (`RateLimited`) with a `Retry-After` value that is not longer than
  #   *max_wait*. The client waits `Retry-After` first. Without a usable value, or
  #   with a longer one, the client raises `RateLimited`.
  # - `Auth::ContractError` with `TransportFailure`. The transport proves that no
  #   request bytes left, so the client sends again without a wait.
  #
  # The client does not send again after `UnknownRemoteOutcome`, HTTP 5xx, or a
  # Slack error, because Slack can already have applied the request.
  # *max_attempts* counts the first attempt. After the last attempt, the client
  # raises the last error. The wait blocks only the calling fiber.
  struct RetryPolicy
    getter max_attempts : Int32
    getter max_wait : Time::Span

    # *sleep* replaces the wait, for example in specs. The default sleeps the calling fiber.
    def initialize(*, @max_attempts : Int32, @max_wait : Time::Span,
                   @sleep : Proc(Time::Span, Nil) = ->(span : Time::Span) { ::sleep(span); nil })
      raise ArgumentError.new("max_attempts must be at least 1") if @max_attempts < 1
      raise ArgumentError.new("max_wait must not be negative") if @max_wait.negative?
    end

    # :nodoc:
    # Returns the wait before attempt `attempt + 1`, or nil when *error* is final.
    def delay(error : Exception, attempt : Int32) : Time::Span?
      return if attempt >= @max_attempts

      case error
      when RateLimited
        retry_after = error.retry_after
        retry_after if retry_after && retry_after <= @max_wait
      when Auth::ContractError
        Time::Span.zero if error.code.transport_failure?
      end
    end

    # :nodoc:
    def wait(span : Time::Span) : Nil
      @sleep.call(span) if span.positive?
    end
  end
end
