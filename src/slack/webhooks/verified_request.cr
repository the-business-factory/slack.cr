require "crypto/subtle"

# Verifies the original body before any JSON or form decoding.
struct Slack::Webhooks::VerifiedRequest
  getter request : HTTP::Request
  getter slack_signature : String
  getter slack_timestamp : String
  getter body : String

  delegate signing_secret, to: Slack.settings
  delegate signing_secret_version, to: Slack.settings
  delegate webhook_delivery_time_limit, to: Slack.settings

  # Callers can supply a fixed UTC clock for tests.
  # Read the request body once. Keep its exact bytes in #body.
  def initialize(@request : HTTP::Request, @clock : Proc(Time) = -> { Time.utc })
    @slack_timestamp = header("X-Slack-Request-Timestamp", :missing_timestamp, :malformed_timestamp)
    @slack_signature = header("X-Slack-Signature", :missing_signature, :malformed_signature)
    body_io = @request.body || raise Errors::InvalidWebhookRequest.new(:missing_body)
    @body = read_body(body_io)
    raise Errors::InvalidWebhookRequest.new(:empty_body) if @body.empty?
  end

  private def read_body(io : IO) : String
    io.gets_to_end
  rescue IO::Error
    raise Errors::InvalidWebhookRequest.new(:unreadable_body)
  end

  def verify!
    raise Errors::ReplayAttack.new if replay_attack?
    validate_signature!
    raise Errors::SignatureMismatch.new unless signature_matches?
    self
  end

  def signature_matches?
    return false unless valid_signature?
    Crypto::Subtle.constant_time_compare(slack_signature, Signature.new(slack_timestamp, body).compute)
  end

  # Accept timestamps at both exact limits. This check does not remove duplicate events.
  def replay_attack?
    timestamp = parsed_timestamp
    now = @clock.call
    timestamp < now - webhook_delivery_time_limit || timestamp > now + webhook_delivery_time_limit
  end

  private def header(name : String, missing : Symbol, malformed : Symbol) : String
    values = @request.headers.get?(name)
    raise Errors::InvalidWebhookRequest.new(missing) unless values
    raise Errors::InvalidWebhookRequest.new(malformed) if values.size != 1 || values.first.empty?
    values.first
  end

  private def parsed_timestamp : Time
    unless /\A[0-9]+\z/.matches?(slack_timestamp) && (seconds = slack_timestamp.to_i64?)
      raise Errors::InvalidWebhookRequest.new(:malformed_timestamp)
    end
    Time.unix(seconds)
  rescue ArgumentError | OverflowError
    raise Errors::InvalidWebhookRequest.new(:malformed_timestamp)
  end

  private def valid_signature? : Bool
    signing_secret_version == "v0" && /\Av0=[0-9a-f]{64}\z/.matches?(slack_signature)
  end

  private def validate_signature!
    raise Errors::InvalidWebhookRequest.new(:malformed_signature) unless valid_signature?
  end
end
