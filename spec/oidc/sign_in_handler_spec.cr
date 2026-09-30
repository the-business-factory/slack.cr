require "../spec_helper"
require "../support/oidc/fixtures"

module SignInHandlerSpecSupport
  extend self

  SESSION = Slack::Auth::Secret.new("trusted-session")
  # Authored from https://docs.slack.dev/reference/methods/openid.connect.token for the fixture attempt.
  EXCHANGE_FORM = "grant_type=authorization_code&client_id=1234.5678&client_secret=synthetic-secret" \
                  "&code=synthetic-code&redirect_uri=https%3A%2F%2Fapp.example.test%2Fslack%2Fsign-in%2Fcallback"

  record Harness, handler : Slack::OIDC::SignInHandler, store : OAuthStateSupport::RecordingStateStore,
    transport : Slack::Testing::RecordingTransport, clock : OAuthStateSupport::Clock

  def harness(configuration : Slack::OIDC::Configuration = OIDCFixtures.configuration, *,
              profile : Bool = true, email : Bool = true) : Harness
    clock = OIDCFixtures.clock
    store = OAuthStateSupport::RecordingStateStore.new(clock)
    transport = Slack::Testing::RecordingTransport.new
    handler = Slack::OIDC::SignInHandler.new(configuration, store, transport,
      profile: profile, email: email, clock: clock, state_ttl: 7.minutes)
    Harness.new(handler, store, transport, clock)
  end

  def configuration(authorization : String = "https://slack.com/openid/connect/authorize",
                    jwks : String = OIDCFixtures::JWKS_URI,
                    redirect : String = "https://app.example.test/slack/sign-in/callback") : Slack::OIDC::Configuration
    Slack::OIDC::Configuration.new(OIDCFixtures::CLIENT_ID, Slack::Auth::Secret.new("synthetic-secret"),
      URI.parse(redirect), authorization_uri: URI.parse(authorization), jwks_uri: URI.parse(jwks))
  end

  # The attempt that the browser round trip would create; its nonce is the fixture tokens' nonce.
  def seed(harness : Harness, state : String = "synthetic-state",
           purpose : Slack::Auth::AuthorizationPurpose = Slack::Auth::AuthorizationPurpose::OIDC) : Nil
    nonce = purpose.oidc? ? Slack::Auth::Secret.new(OIDCFixtures::NONCE) : nil
    harness.store.issue(Slack::Auth::AuthorizationAttempt.new(Slack::Auth::Secret.new(state), SESSION, purpose,
      harness.clock.now + 5.minutes, "https://app.example.test/slack/sign-in/callback", nonce))
  end

  def token_response(id_token : String = OIDCFixtures.token, extra : String = "") : String
    %({"ok":true,"access_token":"#{OIDCFixtures::ACCESS_TOKEN}","token_type":"Bearer","id_token":"#{id_token}"#{extra}})
  end

  def callback(query : String = "code=synthetic-code&state=synthetic-state") : HTTP::Request
    HTTP::Request.new("GET", "/slack/sign-in/callback?#{query}")
  end

  def sign_in(harness : Harness, query : String = "code=synthetic-code&state=synthetic-state") : Slack::OIDC::SignIn
    harness.handler.authenticate_user(callback(query), SESSION)
  end

  def expect_response_error(code : Slack::Auth::ErrorCode, &) : Slack::Auth::ResponseError
    error = expect_raises(Slack::Auth::ResponseError) { yield }
    error.code.should eq code
    error
  end
end

describe Slack::OIDC::SignInHandler do
  describe "#redirect_url" do
    it "issues state and a nonce bound to the session, and asks for the OpenID Connect scopes" do
      harness = SignInHandlerSpecSupport.harness

      url = URI.parse(harness.handler.redirect_url(SignInHandlerSpecSupport::SESSION))

      attempt = harness.store.issued.first
      attempt.state.value.should match /\A[0-9a-f]{64}\z/
      nonce = attempt.nonce.should_not be_nil
      nonce.value.should match /\A[0-9a-f]{64}\z/
      nonce.value.should_not eq attempt.state.value
      attempt.purpose.should eq Slack::Auth::AuthorizationPurpose::OIDC
      attempt.session_binding.value.should eq "trusted-session"
      attempt.expires_at.should eq harness.clock.now + 7.minutes
      attempt.redirect_uri.should eq "https://app.example.test/slack/sign-in/callback"

      "#{url.scheme}://#{url.host}#{url.path}".should eq "https://slack.com/openid/connect/authorize"
      url.query_params.to_h.should eq({
        "response_type" => "code",
        "scope"         => "openid profile email",
        "client_id"     => "1234.5678",
        "redirect_uri"  => "https://app.example.test/slack/sign-in/callback",
        "state"         => attempt.state.value,
        "nonce"         => nonce.value,
      })
      harness.transport.requests.should be_empty
    end

    it "sends the workspace hint only when given and keeps configured query values" do
      harness = SignInHandlerSpecSupport.harness(
        SignInHandlerSpecSupport.configuration("https://slack.com/openid/connect/authorize?tenant=a+b%26c"))

      params = URI.parse(harness.handler.redirect_url(SignInHandlerSpecSupport::SESSION, team: "T-SYNTHETIC")).query_params

      params["team"].should eq "T-SYNTHETIC"
      params["tenant"].should eq "a b&c"
    end

    it "asks only for openid when profile and email are off" do
      harness = SignInHandlerSpecSupport.harness(profile: false, email: false)

      URI.parse(harness.handler.redirect_url(SignInHandlerSpecSupport::SESSION)).query_params["scope"].should eq "openid"
    end

    it "rejects a blank workspace hint" do
      harness = SignInHandlerSpecSupport.harness

      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidConfiguration) do
        harness.handler.redirect_url(SignInHandlerSpecSupport::SESSION, team: " ")
      end
      harness.store.issued.should be_empty
    end
  end

  it "rejects configurations that are not safe" do
    [
      SignInHandlerSpecSupport.configuration("https://slack.com/openid/connect/authorize?nonce=fixed"),
      SignInHandlerSpecSupport.configuration("https://slack.com/openid/connect/authorize?response_type=token"),
      SignInHandlerSpecSupport.configuration("https://slack.com/openid/connect/authorize?team=T1"),
      SignInHandlerSpecSupport.configuration("http://slack.com/openid/connect/authorize"),
      SignInHandlerSpecSupport.configuration(jwks: "http://slack.com/openid/connect/keys"),
      SignInHandlerSpecSupport.configuration(redirect: "https://app.example.test/callback#fragment"),
      SignInHandlerSpecSupport.configuration(redirect: "https://user:pass@app.example.test/callback"),
      Slack::OIDC::Configuration.new(" ", Slack::Auth::Secret.new("synthetic-secret"),
        URI.parse("https://app.example.test/slack/sign-in/callback")),
      Slack::OIDC::Configuration.new("1234.5678", Slack::Auth::Secret.new(" "),
        URI.parse("https://app.example.test/slack/sign-in/callback")),
    ].each do |configuration|
      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidConfiguration) do
        SignInHandlerSpecSupport.harness(configuration)
      end
    end
  end

  describe "#authenticate_user" do
    it "exchanges the code, fetches the key set, and returns the verified identity" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)
      harness.transport.respond(SignInHandlerSpecSupport.token_response)
      harness.transport.respond(OIDCFixtures.jwks)

      sign_in = SignInHandlerSpecSupport.sign_in(harness)

      exchange, keys = harness.transport.requests
      exchange.method.should eq "POST"
      exchange.uri.to_s.should eq "https://slack.com/api/openid.connect.token"
      exchange.headers["Authorization"]?.should be_nil
      exchange.body.should eq SignInHandlerSpecSupport::EXCHANGE_FORM
      keys.method.should eq "GET"
      keys.uri.to_s.should eq "https://slack.com/openid/connect/keys"
      keys.headers["Authorization"]?.should be_nil

      sign_in.identity.user_id.should eq "U-SYNTHETIC"
      sign_in.identity.team_id.should eq "T-SYNTHETIC"
      sign_in.identity.email.should eq "alice@example.test"
      sign_in.access_token.value.should eq "xoxp-synthetic-sign-in"
      sign_in.refresh_token.should be_nil
      sign_in.expires_at.should be_nil
      sign_in.inspect.should eq "Slack::OIDC::SignIn([REDACTED])"
    end

    it "keeps the rotation fields of the exchange" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)
      harness.transport.respond(SignInHandlerSpecSupport.token_response(
        extra: %(,"refresh_token":"xoxe-1-synthetic-refresh","expires_in":43200)))
      harness.transport.respond(OIDCFixtures.jwks)

      sign_in = SignInHandlerSpecSupport.sign_in(harness)

      refresh_token = sign_in.refresh_token.should_not be_nil
      refresh_token.value.should eq "xoxe-1-synthetic-refresh"
      sign_in.expires_at.should eq harness.clock.now + 43200.seconds
      sign_in.token.inspect.should_not contain "xoxe-1-synthetic-refresh"
    end

    it "fetches the key set once for two sign-ins" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness, "first-state")
      SignInHandlerSpecSupport.seed(harness, "second-state")
      harness.transport.respond(SignInHandlerSpecSupport.token_response)
      harness.transport.respond(OIDCFixtures.jwks)
      harness.transport.respond(SignInHandlerSpecSupport.token_response)

      SignInHandlerSpecSupport.sign_in(harness, "code=synthetic-code&state=first-state")
      SignInHandlerSpecSupport.sign_in(harness, "code=synthetic-code&state=second-state")

      harness.transport.requests.map(&.method).should eq ["POST", "GET", "POST"]
    end

    it "sends nothing for unknown state" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)

      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidState) do
        SignInHandlerSpecSupport.sign_in(harness, "code=synthetic-code&state=other-state")
      end
      harness.transport.requests.should be_empty
    end

    it "rejects state that an installation attempt issued" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness, purpose: Slack::Auth::AuthorizationPurpose::Installation)

      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidState) do
        SignInHandlerSpecSupport.sign_in(harness)
      end
      harness.transport.requests.should be_empty
    end

    it "consumes the state before it reads a denial or a malformed code" do
      {
        "error=access_denied&state=synthetic-state"                       => Slack::Auth::ErrorCode::ReauthorizationRequired,
        "error=&state=synthetic-state"                                    => Slack::Auth::ErrorCode::InvalidResponse,
        "code=synthetic-code&code=other-code&state=synthetic-state"       => Slack::Auth::ErrorCode::InvalidResponse,
        "state=synthetic-state"                                           => Slack::Auth::ErrorCode::InvalidResponse,
        "code=synthetic-code&state=synthetic-state&state=synthetic-state" => Slack::Auth::ErrorCode::InvalidState,
      }.each do |query, code|
        harness = SignInHandlerSpecSupport.harness
        SignInHandlerSpecSupport.seed(harness)

        OIDCFixtures.expect_contract_error(code) { SignInHandlerSpecSupport.sign_in(harness, query) }

        harness.transport.requests.should be_empty
        next if code.invalid_state?
        OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidState) do
          SignInHandlerSpecSupport.sign_in(harness)
        end
      end
    end

    it "maps a rejected code to the installation flow's error codes" do
      {
        "invalid_code"      => {Slack::Auth::ErrorCode::ReauthorizationRequired, "invalid_code"},
        "bad_client_secret" => {Slack::Auth::ErrorCode::InvalidResponse, "bad_client_secret"},
        "fatal_error"       => {Slack::Auth::ErrorCode::InvalidResponse, nil},
      }.each do |slack_error, expected|
        harness = SignInHandlerSpecSupport.harness
        SignInHandlerSpecSupport.seed(harness)
        harness.transport.respond(%({"ok":false,"error":"#{slack_error}"}))

        error = SignInHandlerSpecSupport.expect_response_error(expected[0]) do
          SignInHandlerSpecSupport.sign_in(harness)
        end

        error.slack_error.should eq expected[1]
        error.http_status.should eq 200
        harness.transport.requests.size.should eq 1
        OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::InvalidState) do
          SignInHandlerSpecSupport.sign_in(harness)
        end
      end
    end

    it "keeps Retry-After of a rate-limited exchange" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)
      harness.transport.respond("", status: 429, headers: HTTP::Headers{"Retry-After" => "30"})

      error = SignInHandlerSpecSupport.expect_response_error(Slack::Auth::ErrorCode::InvalidResponse) do
        SignInHandlerSpecSupport.sign_in(harness)
      end

      error.slack_error.should eq "ratelimited"
      error.http_status.should eq 429
      error.retry_after.should eq 30.seconds
    end

    it "rejects an exchange response without an ID token" do
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)
      harness.transport.respond(%({"ok":true,"access_token":"xoxp-synthetic-sign-in","token_type":"Bearer"}))

      SignInHandlerSpecSupport.expect_response_error(Slack::Auth::ErrorCode::InvalidResponse) do
        SignInHandlerSpecSupport.sign_in(harness)
      end
      harness.transport.requests.size.should eq 1
    end

    it "rejects an ID token with a bad signature after the key set fetch" do
      header, payload, signature = OIDCFixtures.token.split('.')
      tampered = "#{header}.#{payload}.#{signature[0] == 'A' ? 'B' : 'A'}#{signature[1..]}"
      harness = SignInHandlerSpecSupport.harness
      SignInHandlerSpecSupport.seed(harness)
      harness.transport.respond(SignInHandlerSpecSupport.token_response(tampered))
      harness.transport.respond(OIDCFixtures.jwks)

      error = OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::VerificationFailed) do
        SignInHandlerSpecSupport.sign_in(harness)
      end

      error.message.to_s.should_not contain "alice"
      harness.transport.requests.map(&.method).should eq ["POST", "GET"]
    end

    it "passes a transport failure of the exchange through" do
      clock = OIDCFixtures.clock
      store = OAuthStateSupport::RecordingStateStore.new(clock)
      transport = OAuthStateSupport::RecordingTransport.new
      transport.fail_with(Slack::Auth::ContractError.new(Slack::Auth::ErrorCode::UnknownRemoteOutcome))
      handler = Slack::OIDC::SignInHandler.new(OIDCFixtures.configuration, store, transport, clock: clock)
      store.issue(Slack::Auth::AuthorizationAttempt.new(Slack::Auth::Secret.new("synthetic-state"),
        SignInHandlerSpecSupport::SESSION, Slack::Auth::AuthorizationPurpose::OIDC, clock.now + 5.minutes,
        "https://app.example.test/slack/sign-in/callback", Slack::Auth::Secret.new(OIDCFixtures::NONCE)))

      OIDCFixtures.expect_contract_error(Slack::Auth::ErrorCode::UnknownRemoteOutcome) do
        handler.authenticate_user(SignInHandlerSpecSupport.callback, SignInHandlerSpecSupport::SESSION)
      end
    end
  end

  describe "#refresh" do
    it "sends the refresh grant and returns the new user token" do
      harness = SignInHandlerSpecSupport.harness
      harness.transport.respond(%({"ok":true,"access_token":"xoxe.xoxp-synthetic-new","token_type":"Bearer",) +
                                %("refresh_token":"xoxe-1-synthetic-new","expires_in":43200}))

      token = harness.handler.refresh(Slack::Auth::Secret.new("xoxe-1-synthetic-refresh"))

      request = harness.transport.requests.first
      harness.transport.requests.size.should eq 1
      request.uri.to_s.should eq "https://slack.com/api/openid.connect.token"
      request.headers["Authorization"]?.should be_nil
      # Authored from https://docs.slack.dev/reference/methods/openid.connect.token.
      request.body.should eq "grant_type=refresh_token&client_id=1234.5678&client_secret=synthetic-secret" \
                             "&refresh_token=xoxe-1-synthetic-refresh"
      token.access_token.value.should eq "xoxe.xoxp-synthetic-new"
      refresh_token = token.refresh_token.should_not be_nil
      refresh_token.value.should eq "xoxe-1-synthetic-new"
      token.expires_at.should eq harness.clock.now + 43200.seconds
    end

    it "maps a rejected refresh token to ReauthorizationRequired" do
      harness = SignInHandlerSpecSupport.harness
      harness.transport.respond(%({"ok":false,"error":"invalid_refresh_token"}))

      error = SignInHandlerSpecSupport.expect_response_error(Slack::Auth::ErrorCode::ReauthorizationRequired) do
        harness.handler.refresh(Slack::Auth::Secret.new("xoxe-1-synthetic-refresh"))
      end

      error.slack_error.should eq "invalid_refresh_token"
    end
  end
end
