require "crypto/subtle"
require "http"
require "../auth/clock"
require "../auth/errors"
require "../errors/invalid_webhook_request"
require "../errors/replay_attack"
require "./signature"
require "./verified_request"

# Verifies the signature and timestamp of a Slack HTTP request before any JSON
# or form decoding. Create one verifier with the app signing secret and use it
# for every request.
#
# ```
# verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(signing_secret))
# verified = verifier.verify(request)
# event = Slack::Events.parse(verified.body)
# ```
#
# A verifier does not remove duplicate deliveries. Slack can retry an event.
struct Slack::Webhooks::Verifier
  getter delivery_time_limit : Time::Span

  private SIGNATURE_FORMAT = /\Av0=[0-9a-f]{64}\z/
  private TIMESTAMP_FORMAT = /\A[0-9]+\z/

  # *delivery_time_limit* is the largest accepted difference between the request
  # timestamp and the clock, in both directions.
  def initialize(@signing_secret : Auth::Secret, *, @delivery_time_limit : Time::Span = 5.minutes,
                 @clock : Auth::Clock = Auth::SystemClock.new)
    if @signing_secret.value.blank? || @delivery_time_limit.negative?
      raise Auth::ContractError.new(Auth::ErrorCode::InvalidConfiguration)
    end
  end

  # Reads the request body once and returns it with the verified timestamp.
  # Raises `Errors::InvalidWebhookRequest` for missing or malformed input,
  # `Errors::ReplayAttack` for a timestamp outside the limit, and
  # `Errors::SignatureMismatch` for an incorrect signature.
  def verify(request : HTTP::Request) : VerifiedRequest
    timestamp = header(request, "X-Slack-Request-Timestamp", :missing_timestamp, :malformed_timestamp)
    signature = header(request, "X-Slack-Signature", :missing_signature, :malformed_signature)
    body = read_body(request)
    time = parse_timestamp(timestamp)
    raise Errors::ReplayAttack.new unless within_limit?(time)
    raise Errors::InvalidWebhookRequest.new(:malformed_signature) unless SIGNATURE_FORMAT.matches?(signature)
    expected = Signature.new(@signing_secret, timestamp, body).compute
    raise Errors::SignatureMismatch.new unless Crypto::Subtle.constant_time_compare(signature, expected)
    VerifiedRequest.new(request, body, time)
  end

  private def header(request : HTTP::Request, name : String, missing : Symbol, malformed : Symbol) : String
    values = request.headers.get?(name)
    raise Errors::InvalidWebhookRequest.new(missing) unless values
    raise Errors::InvalidWebhookRequest.new(malformed) if values.size != 1 || values.first.empty?
    values.first
  end

  private def read_body(request : HTTP::Request) : String
    io = request.body || raise Errors::InvalidWebhookRequest.new(:missing_body)
    body = begin
      io.gets_to_end
    rescue IO::Error
      raise Errors::InvalidWebhookRequest.new(:unreadable_body)
    end
    raise Errors::InvalidWebhookRequest.new(:empty_body) if body.empty?
    body
  end

  private def parse_timestamp(value : String) : Time
    seconds = TIMESTAMP_FORMAT.matches?(value) ? value.to_i64? : nil
    raise Errors::InvalidWebhookRequest.new(:malformed_timestamp) unless seconds
    Time.unix(seconds)
  rescue ArgumentError | OverflowError
    raise Errors::InvalidWebhookRequest.new(:malformed_timestamp)
  end

  # Accept timestamps at both exact limits.
  private def within_limit?(timestamp : Time) : Bool
    now = @clock.now
    timestamp >= now - @delivery_time_limit && timestamp <= now + @delivery_time_limit
  end
end
