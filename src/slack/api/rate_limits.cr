require "../auth/clock"
require "./rate_limit_tier"

module Slack::Api
  # :nodoc:
  # Local pacing for one client, keyed by Web API method. It uses the generic cell
  # rate algorithm: no background fiber, and the caller sleeps outside the lock.
  # Pacing lowers the chance of HTTP 429; it does not guarantee Slack acceptance.
  class RateLimits
    @arrivals = {} of String => Time
    @mutex = Mutex.new

    def initialize(@clock : Auth::Clock = Auth::SystemClock.new,
                   @sleep : Proc(Time::Span, Nil) = ->(span : Time::Span) { ::sleep(span); nil })
    end

    def wait(method_path : String, tier : RateLimitTier) : Nil
      delay = reserve(method_path, tier)
      @sleep.call(delay) if delay.positive?
    end

    # Reserves the next slot and returns how long the caller must wait for it.
    private def reserve(method_path : String, tier : RateLimitTier) : Time::Span
      @mutex.synchronize do
        now = @clock.now
        start = {@arrivals[method_path]? || now, now}.max
        @arrivals[method_path] = start + tier.interval
        start - now - tier.interval * (tier.burst - 1)
      end
    end
  end
end
