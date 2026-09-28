require "./error"

module Slack::Api
  # HTTP 429 from Slack. `retry_after` comes from the `Retry-After` header when it is usable.
  class RateLimited < Error
    def initialize(retry_after : Time::Span?)
      super("ratelimited", 429, retry_after: retry_after)
    end
  end
end
