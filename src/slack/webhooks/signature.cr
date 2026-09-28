require "openssl/hmac"
require "../auth/errors"

# Computes the `X-Slack-Signature` value for a request timestamp and its exact body.
#
# ```
# secret = Slack::Auth::Secret.new("synthetic-signing-secret")
# Slack::Webhooks::Signature.new(secret, "1700000000", body).compute # => "v0=..."
# ```
struct Slack::Webhooks::Signature
  # Slack documents only this signature version.
  VERSION = "v0"

  def initialize(@signing_secret : Auth::Secret, @timestamp : String, @body : String)
  end

  def compute : String
    basestring = "#{VERSION}:#{@timestamp}:#{@body}"
    "#{VERSION}=#{OpenSSL::HMAC.hexdigest(:sha256, @signing_secret.value, basestring)}"
  end

  def inspect(io : IO) : Nil
    io << "Slack::Webhooks::Signature([REDACTED])"
  end

  def to_s(io : IO) : Nil
    inspect(io)
  end
end
