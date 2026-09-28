require "http/request"
require "../auth/errors"
require "../webhooks/signature"

# Builds a signed Slack HTTP request for offline tests of request handlers.
# The request passes `Webhooks::Verifier` with the same signing secret while
# the timestamp is inside the verifier's delivery time limit.
#
# ```
# secret = Slack::Auth::Secret.new("synthetic-signing-secret")
# request = Slack::Testing::SignedRequest.build(%({"type":"url_verification","challenge":"c"}), signing_secret: secret)
# Slack::Webhooks::Verifier.new(secret).verify(request).body # => %({"type":"url_verification","challenge":"c"})
# ```
module Slack::Testing::SignedRequest
  # Returns a POST request with *body*, `Content-Type`, `X-Slack-Request-Timestamp`,
  # and `X-Slack-Signature` headers. Add other headers, such as
  # `X-Slack-Retry-Num`, to the returned request.
  def self.build(body : String, *, signing_secret : Auth::Secret, timestamp : Time = Time.utc,
                 path : String = "/slack/events", content_type : String = "application/json") : HTTP::Request
    seconds = timestamp.to_unix.to_s
    headers = HTTP::Headers{
      "Content-Type"              => content_type,
      "X-Slack-Request-Timestamp" => seconds,
      "X-Slack-Signature"         => Webhooks::Signature.new(signing_secret, seconds, body).compute,
    }
    HTTP::Request.new("POST", path, headers, body)
  end
end
