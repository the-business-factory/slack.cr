require "../spec_helper"
require "../support/oidc/fixtures"

module IDTokenVerifierSpecSupport
  extend self

  record Harness, verifier : Slack::OIDC::IDTokenVerifier, transport : Slack::Testing::RecordingTransport,
    clock : OAuthStateSupport::Clock

  def harness(now : Time = OIDCFixtures::ISSUED_AT + 60.seconds) : Harness
    clock = OIDCFixtures.clock(now)
    transport = Slack::Testing::RecordingTransport.new do |_request|
      Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, OIDCFixtures.jwks)
    end
    key_source = Slack::OIDC::KeySource.new(URI.parse(OIDCFixtures::JWKS_URI), transport, clock: clock)
    Harness.new(Slack::OIDC::IDTokenVerifier.new(OIDCFixtures.configuration, key_source, clock: clock),
      transport, clock)
  end

  def verify(harness : Harness, token : String, *, nonce : String = OIDCFixtures::NONCE,
             access_token : String = OIDCFixtures::ACCESS_TOKEN) : Slack::OIDC::Identity
    harness.verifier.verify(Slack::Auth::Secret.new(token), nonce: Slack::Auth::Secret.new(nonce),
      access_token: Slack::Auth::Secret.new(access_token))
  end

  def expect_rejected(token : String, harness : Harness = harness(), *, nonce : String = OIDCFixtures::NONCE,
                      access_token : String = OIDCFixtures::ACCESS_TOKEN) : Nil
    error = OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::VerificationFailed) do
      verify(harness, token, nonce: nonce, access_token: access_token)
    end
    error.message.should eq "Authentication failure: VerificationFailed"
    harness.transport.requests.size.should be <= 1
  end

  # Rejects every signature and records the key it was asked about.
  class RejectingVerifier < Slack::OIDC::SignatureVerifier
    getter kids = [] of String

    def verify(key : Slack::OIDC::SigningKey, signing_input : Bytes, signature : Bytes) : Bool
      @kids << key.kid
      false
    end
  end

  # The valid token with its header replaced; the signature no longer matches.
  def with_header(header : String) : String
    _header, payload, signature = OIDCFixtures.token.split('.')
    "#{Slack::OIDC::Base64URL.encode(header.to_slice)}.#{payload}.#{signature}"
  end
end

describe Slack::OIDC::IDTokenVerifier do
  it "returns the identity of a valid token" do
    harness = IDTokenVerifierSpecSupport.harness

    identity = IDTokenVerifierSpecSupport.verify(harness, OIDCFixtures.token)

    identity.subject.should eq "U-SYNTHETIC"
    identity.user_id.should eq "U-SYNTHETIC"
    identity.team_id.should eq "T-SYNTHETIC"
    identity.email.should eq "alice@example.test"
    identity.email_verified?.should be_true
    identity.name.should eq "Alice Example"
    identity.given_name.should eq "Alice"
    identity.family_name.should eq "Example"
    identity.locale.should eq "en-US"
    identity.authenticated_at.should eq OIDCFixtures::ISSUED_AT
    identity.expires_at.should eq OIDCFixtures::EXPIRES_AT
    identity.inspect.should eq "Slack::OIDC::Identity([REDACTED])"
    harness.transport.requests.size.should eq 1
  end

  it "rejects a changed signature" do
    header, payload, signature = OIDCFixtures.token.split('.')
    bytes = Slack::OIDC::Base64URL.decode(signature).should_not be_nil
    bytes[0] ^= 0x01_u8

    IDTokenVerifierSpecSupport.expect_rejected("#{header}.#{payload}.#{Slack::OIDC::Base64URL.encode(bytes)}")
  end

  it "rejects other algorithms, a missing kid, and critical header parameters before it fetches keys" do
    [
      IDTokenVerifierSpecSupport.with_header(%({"alg":"none","kid":"synthetic-kid"})),
      IDTokenVerifierSpecSupport.with_header(%({"alg":"HS256","kid":"synthetic-kid"})),
      IDTokenVerifierSpecSupport.with_header(%({"kid":"synthetic-kid"})),
      IDTokenVerifierSpecSupport.with_header(%({"alg":"RS256","kid":""})),
      OIDCFixtures.token("missing_kid"),
      OIDCFixtures.token("crit_header"),
    ].each do |token|
      harness = IDTokenVerifierSpecSupport.harness
      IDTokenVerifierSpecSupport.expect_rejected(token, harness)
      harness.transport.requests.should be_empty
    end
  end

  it "rejects malformed segments" do
    header, payload, signature = OIDCFixtures.token.split('.')
    [
      "#{header}.#{payload}",
      "#{header}.#{payload}.#{signature}.#{signature}",
      "#{header}.+#{payload[1..]}.#{signature}",
      "#{header}=.#{payload}.#{signature}",
      "#{Slack::OIDC::Base64URL.encode("[]".to_slice)}.#{payload}.#{signature}",
      "#{Slack::OIDC::Base64URL.encode(Bytes[0xff, 0xfe])}.#{payload}.#{signature}",
    ].each do |token|
      IDTokenVerifierSpecSupport.expect_rejected(token)
    end
  end

  it "rejects an unknown kid after one key set fetch" do
    harness = IDTokenVerifierSpecSupport.harness

    IDTokenVerifierSpecSupport.expect_rejected(OIDCFixtures.token("unknown_kid"), harness)

    harness.transport.requests.size.should eq 1
  end

  it "rejects wrong claims in signed tokens" do
    %w[wrong_nonce wrong_audience wrong_issuer missing_at_hash other_at_hash missing_team_id
      payload_not_json audience_array_without_azp].each do |name|
      IDTokenVerifierSpecSupport.expect_rejected(OIDCFixtures.token(name))
    end
  end

  it "rejects a nonce or access token other than the ones of the attempt" do
    IDTokenVerifierSpecSupport.expect_rejected(OIDCFixtures.token, nonce: "another-nonce")
    IDTokenVerifierSpecSupport.expect_rejected(OIDCFixtures.token, access_token: "xoxp-another-token")
  end

  it "accepts an audience array whose authorized party is the client" do
    harness = IDTokenVerifierSpecSupport.harness

    IDTokenVerifierSpecSupport.verify(harness, OIDCFixtures.token("audience_array_with_azp"))
      .user_id.should eq "U-SYNTHETIC"
  end

  it "allows 60 seconds of clock skew at expiry and issue time" do
    token = OIDCFixtures.token
    late = IDTokenVerifierSpecSupport.harness(OIDCFixtures::EXPIRES_AT + 59.seconds)
    early = IDTokenVerifierSpecSupport.harness(OIDCFixtures::ISSUED_AT - 60.seconds)

    IDTokenVerifierSpecSupport.verify(late, token).user_id.should eq "U-SYNTHETIC"
    IDTokenVerifierSpecSupport.verify(early, token).user_id.should eq "U-SYNTHETIC"
    IDTokenVerifierSpecSupport.expect_rejected(token, IDTokenVerifierSpecSupport.harness(OIDCFixtures::EXPIRES_AT + 61.seconds))
    IDTokenVerifierSpecSupport.expect_rejected(token, IDTokenVerifierSpecSupport.harness(OIDCFixtures::ISSUED_AT - 61.seconds))
  end

  it "uses the signature verifier it is given" do
    harness = IDTokenVerifierSpecSupport.harness
    key_source = Slack::OIDC::KeySource.new(URI.parse(OIDCFixtures::JWKS_URI), harness.transport, clock: harness.clock)
    rejecting = IDTokenVerifierSpecSupport::RejectingVerifier.new
    verifier = Slack::OIDC::IDTokenVerifier.new(OIDCFixtures.configuration, key_source,
      signature_verifier: rejecting, clock: harness.clock)

    OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::VerificationFailed) do
      verifier.verify(Slack::Auth::Secret.new(OIDCFixtures.token), nonce: Slack::Auth::Secret.new(OIDCFixtures::NONCE),
        access_token: Slack::Auth::Secret.new(OIDCFixtures::ACCESS_TOKEN))
    end
    rejecting.kids.should eq ["synthetic-kid"]
  end
end
