require "../spec_helper"

module SignedRequestSpec
  NOW    = Time.unix(1_700_000_000)
  SECRET = "synthetic-signing-secret"
  BODY   = "{ \"challenge\": \"snowman \\u2603\" }\n"
  # Synthetic vector independently calculated with Python stdlib hmac/sha256:
  # hmac.new(b'synthetic-signing-secret',
  #   b'v0:1700000000:{ "challenge": "snowman \\u2603" }\n', hashlib.sha256)
  SIGNATURE = "v0=464740e2abca0af4fd5c59f7c35b13f39b4fafc75c111e6487b037cfb91f05fd"

  def self.request(body : String? = BODY, timestamp = NOW.to_unix.to_s, signature : String? = nil)
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => signature || Slack::Webhooks::Signature.new(timestamp, body || "").compute,
    }
    HTTP::Request.new("POST", "/signed", headers, body)
  end

  def self.verify(request)
    Slack::Webhooks::VerifiedRequest.new(request, clock: -> { NOW }).verify!
  end
end

describe Slack::Webhooks::VerifiedRequest do
  around_each do |example|
    secret = Slack.settings.signing_secret
    version = Slack.settings.signing_secret_version
    limit = Slack.settings.webhook_delivery_time_limit
    begin
      Slack.configure do |settings|
        settings.signing_secret = SignedRequestSpec::SECRET
        settings.signing_secret_version = "v0"
        settings.webhook_delivery_time_limit = 5.minutes
      end
      example.run
    ensure
      Slack.configure do |settings|
        settings.signing_secret = secret
        settings.signing_secret_version = version
        settings.webhook_delivery_time_limit = limit
      end
    end
  end

  it "matches an independent fixed HMAC vector and retains exact bytes" do
    Slack::Webhooks::Signature.new("1700000000", SignedRequestSpec::BODY).compute.should eq SignedRequestSpec::SIGNATURE
    verified = SignedRequestSpec.verify(SignedRequestSpec.request(signature: SignedRequestSpec::SIGNATURE))
    verified.body.to_slice.should eq SignedRequestSpec::BODY.to_slice
    verified.verify!.body.should eq SignedRequestSpec::BODY
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
    Slack.configure(&.webhook_delivery_time_limit = 10.seconds)
    [-10, 10].each do |offset|
      SignedRequestSpec.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
    end
    [-11, 11].each do |offset|
      expect_raises(Slack::Errors::ReplayAttack) do
        SignedRequestSpec.verify(SignedRequestSpec.request(timestamp: (SignedRequestSpec::NOW.to_unix + offset).to_s))
      end
    end
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

  it "does not enable another protocol through the legacy version setting" do
    Slack.configure(&.signing_secret_version = "v1")
    expect_raises(Slack::Errors::InvalidWebhookRequest) { SignedRequestSpec.verify(SignedRequestSpec.request) }
  end

  it "rejects validly shaped incorrect digests" do
    expect_raises(Slack::Errors::SignatureMismatch, "Slack webhook signature mismatch") do
      SignedRequestSpec.verify(SignedRequestSpec.request(signature: "v0=#{"0" * 64}"))
    end
  end

  it "verifies raw JSON and form bytes through every process entry point" do
    timestamp = Time.utc.to_unix.to_s
    Slack.process_webhook(SignedRequestSpec.request(File.read("spec/fixtures/events/url_verification.json"), timestamp)).should be_a Slack::UrlVerification
    form = File.read("spec/fixtures/commands/encoded_names.txt")
    Slack.process_command(SignedRequestSpec.request(form, timestamp)).should be_a Slack::Command
    interaction = "payload=%7B%20%22type%22%3A%20%22shortcut%22%20%7D"
    Slack.process_interaction(SignedRequestSpec.request(interaction, timestamp)).should be_a Slack::Interactions::Shortcut
  end

  it "verifies before parsing through every process entry point" do
    timestamp = Time.utc.to_unix.to_s
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_webhook(SignedRequestSpec.request("invalid json", timestamp, "v0=#{"0" * 64}")) }
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_command(SignedRequestSpec.request("invalid form", timestamp, "v0=#{"0" * 64}")) }
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_interaction(SignedRequestSpec.request("no payload", timestamp, "v0=#{"0" * 64}")) }
  end
  it "rejects whitespace and equivalent form re-encoding through the process entry points" do
    timestamp = Time.utc.to_unix.to_s
    json = File.read("spec/fixtures/events/url_verification.json")
    request = SignedRequestSpec.request(json, timestamp)
    request.body = IO::Memory.new(json + " ")
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_webhook(request) }

    form = File.read("spec/fixtures/commands/encoded_names.txt")
    request = SignedRequestSpec.request(form, timestamp)
    request.body = IO::Memory.new(form + "&")
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_command(request) }

    form = "payload=%7B%22type%22%3A%22shortcut%22%7D"
    request = SignedRequestSpec.request(form, timestamp)
    request.body = IO::Memory.new(form.sub("%7B", "%7b"))
    expect_raises(Slack::Errors::SignatureMismatch) { Slack.process_interaction(request) }
  end

  it "normalizes missing inputs through every process entry point" do
    expect_raises(Slack::Errors::InvalidWebhookRequest) { Slack.process_webhook(HTTP::Request.new("POST", "/")) }
    expect_raises(Slack::Errors::InvalidWebhookRequest) { Slack.process_command(HTTP::Request.new("POST", "/")) }
    expect_raises(Slack::Errors::InvalidWebhookRequest) { Slack.process_interaction(HTTP::Request.new("POST", "/")) }
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
