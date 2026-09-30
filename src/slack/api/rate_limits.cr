require "../auth/clock"
require "./rate_limit_tier"

module Slack::Api
  # Local pacing for one client, keyed by Web API method. It uses the generic cell
  # rate algorithm: no background fiber, and the caller sleeps outside the lock.
  # The first calls to a method, up to the tier's burst, do not wait. After the
  # burst, calls are spaced at the tier's interval.
  # Pacing lowers the chance of HTTP 429; it does not guarantee Slack acceptance.
  #
  # `Client.new` builds one `RateLimits` by default. Give another with
  # *rate_limits*. *clock* and *sleep* are for tests.
  # `Slack::Testing::InstantRateLimits` never waits; use it in offline specs.
  class RateLimits
    @arrivals = {} of String => Time
    @mutex = Mutex.new

    def initialize(@clock : Auth::Clock = Auth::SystemClock.new,
                   @sleep : Proc(Time::Span, Nil) = ->(span : Time::Span) { ::sleep(span); nil })
    end

    # Waits until *method_path* can be called again under *tier*.
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
