require "../api/rate_limits"

# A `Slack::Api::RateLimits` that never waits. Use it in offline specs that
# make more calls to one method than the method's burst on one client.
# Production clients keep the default `RateLimits`.
#
# ```
# client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport,
#   rate_limits: Slack::Testing::InstantRateLimits.new)
# ```
class Slack::Testing::InstantRateLimits < Slack::Api::RateLimits
  def wait(method_path : String, tier : Slack::Api::RateLimitTier) : Nil
  end
end
