require "../spec_helper"
require "../support/oidc/fixtures"

module KeySourceSpecSupport
  extend self

  def source(transport : Slack::Auth::Transport, clock : Slack::Auth::Clock) : Slack::OIDC::KeySource
    Slack::OIDC::KeySource.new(URI.parse(OIDCFixtures::JWKS_URI), transport, clock: clock)
  end

  def transport : Slack::Testing::RecordingTransport
    Slack::Testing::RecordingTransport.new { |_request| Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, OIDCFixtures.jwks) }
  end
end

describe Slack::OIDC::KeySource do
  it "fetches the key set once, without credentials" do
    transport = KeySourceSpecSupport.transport
    source = KeySourceSpecSupport.source(transport, OIDCFixtures.clock)

    source.key("synthetic-kid").should_not be_nil
    source.key("synthetic-kid").should_not be_nil

    transport.requests.size.should eq 1
    request = transport.requests.first
    request.method.should eq "GET"
    request.uri.to_s.should eq "https://slack.com/openid/connect/keys"
    request.headers["Accept"].should eq "application/json"
    request.headers["Authorization"]?.should be_nil
    request.body.should be_nil
  end

  it "fetches again for an unknown kid at most once per refresh interval" do
    transport = KeySourceSpecSupport.transport
    clock = OIDCFixtures.clock
    source = KeySourceSpecSupport.source(transport, clock)
    source.key("synthetic-kid")

    clock.now += 5.minutes
    source.key("rotated-kid").should be_nil
    transport.requests.size.should eq 2

    clock.now += 4.minutes
    source.key("another-kid").should be_nil
    transport.requests.size.should eq 2

    clock.now += 1.minute
    source.key("another-kid").should be_nil
    transport.requests.size.should eq 3
  end

  it "does not fetch twice when the first fetch lacks the kid" do
    transport = KeySourceSpecSupport.transport
    source = KeySourceSpecSupport.source(transport, OIDCFixtures.clock)

    source.key("rotated-kid").should be_nil

    transport.requests.size.should eq 1
  end

  it "fetches again after the 24-hour lifetime" do
    transport = KeySourceSpecSupport.transport
    clock = OIDCFixtures.clock
    source = KeySourceSpecSupport.source(transport, clock)
    source.key("synthetic-kid")

    clock.now += 24.hours - 1.second
    source.key("synthetic-kid")
    transport.requests.size.should eq 1

    clock.now += 1.second
    source.key("synthetic-kid").should_not be_nil
    transport.requests.size.should eq 2
  end

  it "raises for a failed status or a bad document, then fetches again" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond("unavailable", status: 500)
    transport.respond(%({"keys":[]}))
    transport.respond(OIDCFixtures.jwks)
    source = KeySourceSpecSupport.source(transport, OIDCFixtures.clock)

    error = OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidResponse) do
      source.key("synthetic-kid")
    end
    error.http_status.should eq 500
    OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidResponse) { source.key("synthetic-kid") }
    source.key("synthetic-kid").should_not be_nil
    transport.requests.size.should eq 3
  end

  it "fetches again for a known kid after a failed refresh" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(OIDCFixtures.jwks)
    transport.respond("unavailable", status: 503)
    transport.respond(OIDCFixtures.jwks)
    clock = OIDCFixtures.clock
    source = KeySourceSpecSupport.source(transport, clock)
    source.key("synthetic-kid")

    clock.now += 5.minutes
    OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidResponse) { source.key("rotated-kid") }
    source.key("synthetic-kid").should_not be_nil

    transport.requests.size.should eq 3
  end

  it "passes a transport failure through and fetches again on the next call" do
    transport = OAuthStateSupport::RecordingTransport.new
    transport.fail_with(Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::TransportFailure))
    source = KeySourceSpecSupport.source(transport, OIDCFixtures.clock)

    OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::TransportFailure) { source.key("synthetic-kid") }
    OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::TransportFailure) { source.key("synthetic-kid") }
    transport.requests.size.should eq 2
  end

  it "rejects a key set URI that is not HTTPS or spans that are not positive" do
    transport = KeySourceSpecSupport.transport
    [
      -> { Slack::OIDC::KeySource.new(URI.parse("http://slack.com/openid/connect/keys"), transport) },
      -> { Slack::OIDC::KeySource.new(URI.parse("http://localhost/keys"), transport) },
      -> { Slack::OIDC::KeySource.new(URI.parse("/openid/connect/keys"), transport) },
      -> { Slack::OIDC::KeySource.new(URI.parse(OIDCFixtures::JWKS_URI), transport, ttl: Time::Span.zero) },
      -> { Slack::OIDC::KeySource.new(URI.parse(OIDCFixtures::JWKS_URI), transport, refresh_interval: -1.second) },
    ].each do |build|
      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidConfiguration) { build.call }
    end
  end
end
