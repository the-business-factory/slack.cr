# A request that `Verifier#verify` accepted. `#body` holds the exact bytes that
# Slack signed; decode them with `Slack::Events.parse`, `Slack::Commands.parse`,
# or `Slack::Interactions.parse`.
struct Slack::Webhooks::VerifiedRequest
  # The original request. Its body stream has been read; use `#body`.
  getter request : HTTP::Request
  getter body : String
  # The verified `X-Slack-Request-Timestamp` value.
  getter timestamp : Time

  def initialize(@request : HTTP::Request, @body : String, @timestamp : Time)
  end
end
