require "../spec_helper"

module SignedRequestSpec
  NOW    = Time.unix(1_700_000_000)
  SECRET = Slack::Auth::Secret.new("synthetic-signing-secret")
  BODY   = "{ \"challenge\": \"snowman \\u2603\" }\n"
  # Synthetic vector independently calculated with Python stdlib hmac/sha256:
  # hmac.new(b'synthetic-signing-secret',
  #   b'v0:1700000000:{ "challenge": "snowman \\u2603" }\n', hashlib.sha256)
  SIGNATURE = "v0=464740e2abca0af4fd5c59f7c35b13f39b4fafc75c111e6487b037cfb91f05fd"

  def self.request(body : String? = BODY, timestamp = NOW.to_unix.to_s, signature : String? = nil)
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => signature || Slack::Webhooks::Signature.new(SECRET, timestamp, body || "").compute,
    }
    HTTP::Request.new("POST", "/signed", headers, body)
  end

  class FixedClock < Slack::Auth::Clock
    def initialize(@now : Time)
    end

    def now : Time
      @now
    end
  end

  def self.verifier(limit : Time::Span = 5.minutes) : Slack::Webhooks::Verifier
    Slack::Webhooks::Verifier.new(SECRET, delivery_time_limit: limit, clock: FixedClock.new(NOW))
  end

  def self.verify(request : HTTP::Request) : Slack::Webhooks::VerifiedRequest
    verifier.verify(request)
  end
end

describe Slack::Webhooks::Verifier do
  it "matches an independent fixed HMAC vector and retains exact bytes" do
    Slack::Webhooks::Signature.new(SignedRequestSpec::SECRET, "1700000000", SignedRequestSpec::BODY).compute.should eq SignedRequestSpec::SIGNATURE
    verified = SignedRequestSpec.verify(SignedRequestSpec.request(signature: SignedRequestSpec::SIGNATURE))
    verified.body.to_slice.should eq SignedRequestSpec::BODY.to_slice
    verified.timestamp.should eq SignedRequestSpec::NOW
  end

  it "rejects changed body content and whitespace" do
    [SignedRequestSpec::BODY.strip, SignedRequestSpec::BODY.sub("snowman", "tampered")].each do |body|
      expect_raises(Slack::Errors::SignatureMismatch) do
        SignedRequestSpec.verify(SignedRequestSpec.request(body, signature: SignedRequestSpec::SIGNATURE))
      end
    end
  end

  it "preserves non-ASCII, NUL, and CRLF bytes in a streamed body" do
    body = "a=☃\u0000\r\n&b=%20+"
    request = SignedRequestSpec.request(body)
    request.body = IO::Memory.new(body)
    SignedRequestSpec.verify(request).body.to_slice.should eq body.to_slice
  end

  [-300, 0, 300].each do |offset|
    it "accepts the inclusive timestamp offset #{offset}" do
      SignedRequestSpec.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
    end
  end

  [-301, 301].each do |offset|
    it "rejects timestamp offset #{offset}" do
      expect_raises(Slack::Errors::ReplayAttack) do
        SignedRequestSpec.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
      end
    end
  end

  it "honors a custom symmetric delivery limit" do
    verifier = SignedRequestSpec.verifier(10.seconds)
    [-10, 10].each do |offset|
      verifier.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
    end
    [-11, 11].each do |offset|
      expect_raises(Slack::Errors::ReplayAttack) do
        verifier.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
      end
    end
  end

  it "rejects a blank signing secret and a negative delivery limit" do
    error = expect_raises(Slack::Auth::ContractError) { SignedRequestSpec.verifier(-1.second) }
    error.code.should eq Slack::Auth::ErrorCode::InvalidConfiguration
    error = expect_raises(Slack::Auth::ContractError) do
      Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(" \t"))
    end
    error.code.should eq Slack::Auth::ErrorCode::InvalidConfiguration
  end

  it "rejects a request signed with another secret" do
    other = Slack::Auth::Secret.new("another-synthetic-secret")
    timestamp = SignedRequestSpec::NOW.to_unix.to_s
    signature = Slack::Webhooks::Signature.new(other, timestamp, SignedRequestSpec::BODY).compute
    expect_raises(Slack::Errors::SignatureMismatch) do
      SignedRequestSpec.verify(SignedRequestSpec.request(signature: signature))
    end
  end

  it "redacts the signing secret when inspected" do
    SignedRequestSpec.verifier.inspect.should_not contain("synthetic-signing-secret")
    Slack::Webhooks::Signature.new(SignedRequestSpec::SECRET, "1", "body").inspect.should_not contain("synthetic-signing-secret")
  end

  ["", "abc", "1700000000junk", "1700000000.0", " 1700000000", "+1700000000", "-1", "99999999999999999999999", Int64::MAX.to_s].each do |timestamp|
    it "normalizes invalid timestamp #{timestamp.inspect}" do
      error = expect_raises(Slack::Errors::InvalidWebhookRequest) do
        SignedRequestSpec.verify(SignedRequestSpec.request(timestamp: timestamp))
      end
      error.reason.should eq :malformed_timestamp
    end
  end

  ["", "v1=#{"a" * 64}", "v0=#{"a" * 63}", "v0=#{"a" * 65}", "v0=#{"g" * 64}", "v0=#{"A" * 64}", "v0=#{"a" * 64} "].each do |signature|
    it "rejects malformed signature #{signature.inspect}" do
      error = expect_raises(Slack::Errors::InvalidWebhookRequest) do
        SignedRequestSpec.verify(SignedRequestSpec.request(signature: signature))
      end
      error.reason.should eq :malformed_signature
    end
  end

  {"X-Slack-Signature" => :missing_signature, "X-Slack-Request-Timestamp" => :missing_timestamp}.each do |header, reason|
    it "normalizes missing #{header}" do
      request = SignedRequestSpec.request
      request.headers.delete(header)
      expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(request) }.reason.should eq reason
    end

    it "rejects duplicate #{header}" do
      request = SignedRequestSpec.request
      request.headers.add(header, request.headers[header])
      expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(request) }
    end
  end

  it "rejects missing and empty bodies with stable errors" do
    expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(SignedRequestSpec.request(nil)) }.reason.should eq :missing_body
    request = SignedRequestSpec.request
    request.body = IO::Memory.new
    expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(request) }.reason.should eq :empty_body
  end

  it "rejects validly shaped incorrect digests" do
    expect_raises(Slack::Errors::SignatureMismatch, "Slack webhook signature mismatch") do
      SignedRequestSpec.verify(SignedRequestSpec.request(signature: "v0=#{"0" * 64}"))
    end
  end

  it "parses verified JSON and form bytes with each payload parser" do
    json = File.read("spec/fixtures/events/url_verification.json")
    verified = SignedRequestSpec.verify(SignedRequestSpec.request(json))
    Slack::Events.parse(verified.body).should be_a Slack::UrlVerification

    form = File.read("spec/fixtures/commands/encoded_names.txt")
    verified = SignedRequestSpec.verify(SignedRequestSpec.request(form))
    Slack::Commands.parse(verified.body).should be_a Slack::Command

    interaction = "payload=%7B%20%22type%22%3A%20%22shortcut%22%20%7D"
    verified = SignedRequestSpec.verify(SignedRequestSpec.request(interaction))
    Slack::Interactions.parse(verified.body).should be_a Slack::Interactions::Shortcut
  end

  it "rejects equivalent form re-encoding" do
    form = "payload=%7B%22type%22%3A%22shortcut%22%7D"
    request = SignedRequestSpec.request(form)
    request.body = IO::Memory.new(form.sub("%7B", "%7b"))
    expect_raises(Slack::Errors::SignatureMismatch) { SignedRequestSpec.verify(request) }
  end

  it "normalizes IO failures without exposing their messages" do
    request = SignedRequestSpec.request
    stream = IO::Memory.new("secret body")
    stream.close
    request.body = stream
    error = expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(request) }
    error.reason.should eq :unreadable_body
    error.message.should eq "Invalid Slack webhook request: unreadable_body"
  end
end
