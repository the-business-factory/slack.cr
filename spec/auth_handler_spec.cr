require "./spec_helper"
require "./support/auth/oauth_state_fakes"

module OAuthHandlerSpecSupport
  extend self

  def secret(value : String = "trusted-session") : Slack::Auth::Secret
    Slack::Auth::Secret.new(value)
  end

  def configuration(authorization : String = "https://auth.example.test/oauth/v2/authorize?team=T1",
                    token : String = "https://token.example.test/custom/oauth.v2.access",
                    redirect : String = "https://app.example.test/install/callback?tenant=one&route=a+b%2Fc%26d",
                    client_id : String = "client+id&value",
                    client_secret : String = "dummy+secret&value=100%") : Slack::Auth::OAuthConfiguration
    Slack::Auth::OAuthConfiguration.new(
      URI.parse(authorization),
      URI.parse(token),
      client_id,
      secret(client_secret),
      URI.parse(redirect)
    )
  end

  def handler(configuration : Slack::Auth::OAuthConfiguration,
              store : Slack::Auth::StateStore,
              transport : Slack::Auth::Transport,
              clock : Slack::Auth::Clock,
              bot_scopes : Array(String) = ["chat:write", "commands"],
              user_scopes : Array(String) = ["users:read"],
              state_ttl : Time::Span = 10.minutes) : Slack::AuthHandler
    Slack::AuthHandler.new(configuration, store, transport,
      bot_scopes: bot_scopes, user_scopes: user_scopes, clock: clock, state_ttl: state_ttl)
  end

  def issue(handler : Slack::AuthHandler, session : String = "trusted-session") : String
    URI.parse(handler.redirect_url(secret(session))).query_params["state"]
  end

  def callback(query : String) : HTTP::Request
    HTTP::Request.new("GET", "/install/callback?#{query}")
  end

  def encoded_callback(state : String, code : String = "dummy+code&value=100%") : HTTP::Request
    callback(URI::Params.encode({"state" => state, "code" => code}))
  end

  def fixture(name : String = "bot_workspace") : String
    File.read("spec/fixtures/oauth_responses/#{name}.json")
  end

  def response(name : String = "bot_workspace", status : Int32 = 200,
               headers : HTTP::Headers = HTTP::Headers.new) : Slack::Auth::TransportResponse
    Slack::Auth::TransportResponse.new(status, headers, fixture(name))
  end

  def expect_contract_error(code : Slack::Auth::ErrorCode, &)
    error = expect_raises(Slack::Auth::ContractError) { yield }
    error.code.should eq(code)
    error
  end

  def bounded_result(channel : Channel(Symbol)) : Symbol
    select
    when value = channel.receive
      value
    when timeout(1.second)
      raise "Timed out waiting for OAuth callback"
    end
  end
end

describe Slack::AuthHandler do
  it "issues unique 256-bit state bound to the trusted session and exact expiry" do
    clock = OAuthStateSupport::Clock.new
    store = OAuthStateSupport::RecordingStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock,
      state_ttl: 7.minutes)

    states = Array.new(16) { OAuthHandlerSpecSupport.issue(handler, "browser-session") }
    states.uniq.size.should eq(16)
    states.each(&.should(match(/\A[0-9a-f]{64}\z/)))
    store.issued.map(&.state.value).should eq(states)
    store.issued.each do |attempt|
      attempt.session_binding.value.should eq("browser-session")
      attempt.purpose.installation?.should be_true
      attempt.expires_at.should eq(clock.now + 7.minutes)
      attempt.redirect_uri.should eq(OAuthHandlerSpecSupport.configuration.redirect_uri.to_s)
    end
  end

  it "encodes special values, preserves benign authorization queries, and separates scopes" do
    clock = OAuthStateSupport::Clock.new
    store = OAuthStateSupport::RecordingStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    redirect = "https://app.example.test/callback?plus=a+b&symbols=%26%3D%25&unicode=%E9%9B%AA"
    configuration = OAuthHandlerSpecSupport.configuration(
      authorization: "https://auth.alt.example/oauth/custom?team=T%2B1&prompt=consent",
      redirect: redirect,
      client_id: "client+&=%雪"
    )
    handler = OAuthHandlerSpecSupport.handler(configuration, store, transport, clock,
      bot_scopes: ["commands", "chat:write"], user_scopes: ["users:read", "channels:read"])

    authorization = URI.parse(handler.redirect_url(OAuthHandlerSpecSupport.secret))
    authorization.host.should eq("auth.alt.example")
    authorization.path.should eq("/oauth/custom")
    authorization.query_params.to_a.count { |name, _| name == "state" }.should eq(1)
    authorization.query_params["team"].should eq("T+1")
    authorization.query_params["prompt"].should eq("consent")
    authorization.query_params["client_id"].should eq("client+&=%雪")
    authorization.query_params["redirect_uri"].should eq(redirect)
    authorization.query_params["scope"].should eq("commands,chat:write")
    authorization.query_params["user_scope"].should eq("users:read,channels:read")
  end

  it "snapshots endpoint URIs and scope arrays at construction" do
    clock = OAuthStateSupport::Clock.new
    store = OAuthStateSupport::RecordingStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    authorization_uri = URI.parse("https://auth.original.test/authorize")
    token_uri = URI.parse("https://token.original.test/access")
    redirect_uri = URI.parse("https://app.original.test/callback?route=one")
    configuration = Slack::Auth::OAuthConfiguration.new(authorization_uri, token_uri,
      "original-client", OAuthHandlerSpecSupport.secret("original-secret"), redirect_uri)
    bot_scopes = ["commands"]
    user_scopes = ["users:read"]
    handler = OAuthHandlerSpecSupport.handler(configuration, store, transport, clock,
      bot_scopes: bot_scopes, user_scopes: user_scopes)

    authorization_uri.host = "evil.example"
    token_uri.host = "evil.example"
    redirect_uri.host = "evil.example"
    bot_scopes << "admin"
    user_scopes.clear
    transport.enqueue(OAuthHandlerSpecSupport.response)

    authorization = URI.parse(handler.redirect_url(OAuthHandlerSpecSupport.secret))
    authorization.host.should eq("auth.original.test")
    authorization.query_params["scope"].should eq("commands")
    authorization.query_params["user_scope"].should eq("users:read")
    state = authorization.query_params["state"]
    handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)

    request = transport.requests.first
    request.uri.host.should eq("token.original.test")
    form = URI::Params.parse(request.body || raise "Missing exchange body")
    form["client_id"].should eq("original-client")
    form["client_secret"].should eq("original-secret")
    form["redirect_uri"].should eq("https://app.original.test/callback?route=one")
  end

  it "rejects blank settings, unsafe URIs, reserved authorization queries, and nonpositive TTL" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    invalid = [] of Slack::Auth::OAuthConfiguration
    invalid << OAuthHandlerSpecSupport.configuration(client_id: " \t")
    invalid << OAuthHandlerSpecSupport.configuration(client_secret: " \t")
    invalid << OAuthHandlerSpecSupport.configuration(authorization: "http://auth.example/authorize")
    invalid << OAuthHandlerSpecSupport.configuration(token: "/oauth.v2.access")
    invalid << OAuthHandlerSpecSupport.configuration(redirect: "https://user:password@app.example/callback")
    invalid << OAuthHandlerSpecSupport.configuration(token: "https://token.example/access#fragment")
    invalid.each do |configuration|
      OAuthHandlerSpecSupport.expect_contract_error(:invalid_configuration) do
        OAuthHandlerSpecSupport.handler(configuration, store, transport, clock)
      end
    end

    %w[client_id redirect_uri scope state user_scope].each do |name|
      configuration = OAuthHandlerSpecSupport.configuration(
        authorization: "https://auth.example/authorize?#{name}=forged"
      )
      OAuthHandlerSpecSupport.expect_contract_error(:invalid_configuration) do
        OAuthHandlerSpecSupport.handler(configuration, store, transport, clock)
      end
    end
    [Time::Span.zero, -1.nanosecond].each do |ttl|
      OAuthHandlerSpecSupport.expect_contract_error(:invalid_configuration) do
        OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock,
          state_ttl: ttl)
      end
    end
    transport.requests.should be_empty
  end

  it "fails closed on a generated state collision without retrying" do
    clock = OAuthStateSupport::Clock.new
    store = OAuthStateSupport::ConflictStateStore.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store,
      OAuthStateSupport::RecordingTransport.new, clock)
    OAuthHandlerSpecSupport.expect_contract_error(:conflict) do
      handler.redirect_url(OAuthHandlerSpecSupport.secret)
    end
    store.issue_count.should eq(1)
  end

  it "requires exactly one nonblank state without consuming a valid duplicate" do
    clock = OAuthStateSupport::Clock.new
    store = OAuthStateSupport::RecordingStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)
    ["code=x", "state=&code=x"].each do |query|
      OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
        handler.authenticate_user(OAuthHandlerSpecSupport.callback(query), OAuthHandlerSpecSupport.secret)
      end
    end

    state = OAuthHandlerSpecSupport.issue(handler)
    duplicate = "state=#{state}&state=#{state}&code=x"
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.callback(duplicate), OAuthHandlerSpecSupport.secret)
    end
    transport.enqueue(OAuthHandlerSpecSupport.response)
    handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)
    transport.requests.size.should eq(1)
  end

  it "rejects wrong, expired, replayed, cross-session, and wrong-purpose states before exchange" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock,
      state_ttl: 1.minute)

    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback("unknown"), OAuthHandlerSpecSupport.secret)
    end
    cross_session = OAuthHandlerSpecSupport.issue(handler, "correct-session")
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(cross_session),
        OAuthHandlerSpecSupport.secret("wrong-session"))
    end
    transport.enqueue(OAuthHandlerSpecSupport.response)
    handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(cross_session),
      OAuthHandlerSpecSupport.secret("correct-session"))
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(cross_session),
        OAuthHandlerSpecSupport.secret("correct-session"))
    end

    expired = OAuthHandlerSpecSupport.issue(handler)
    clock.now += 1.minute
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(expired), OAuthHandlerSpecSupport.secret)
    end

    oidc = Slack::Auth::AuthorizationAttempt.new(OAuthHandlerSpecSupport.secret("oidc-state"),
      OAuthHandlerSpecSupport.secret, :oidc, clock.now + 1.minute,
      "https://app.example.test/login", OAuthHandlerSpecSupport.secret("oidc-nonce"))
    store.issue(oidc)
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback("oidc-state"), OAuthHandlerSpecSupport.secret)
    end
    store.consume(OAuthHandlerSpecSupport.secret("oidc-state"), OAuthHandlerSpecSupport.secret, :oidc).should eq(oidc)
    transport.requests.size.should eq(1)
  end

  it "spends valid state before denial or malformed code and sends no exchange" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)

    callbacks = {
      {"error=access_denied", Slack::Auth::ErrorCode::ReauthorizationRequired},
      {"error=attacker-controlled-text", Slack::Auth::ErrorCode::ReauthorizationRequired},
      {"code=forged&error=access_denied", Slack::Auth::ErrorCode::ReauthorizationRequired},
      {"", Slack::Auth::ErrorCode::InvalidResponse},
      {"code=", Slack::Auth::ErrorCode::InvalidResponse},
      {"code=one&code=two", Slack::Auth::ErrorCode::InvalidResponse},
      {"error=", Slack::Auth::ErrorCode::InvalidResponse},
      {"error=one&error=two", Slack::Auth::ErrorCode::InvalidResponse},
    }
    callbacks.each do |suffix, expected|
      state = OAuthHandlerSpecSupport.issue(handler)
      separator = suffix.empty? ? "" : "&#{suffix}"
      error = OAuthHandlerSpecSupport.expect_contract_error(expected) do
        handler.authenticate_user(OAuthHandlerSpecSupport.callback("state=#{state}#{separator}"),
          OAuthHandlerSpecSupport.secret)
      end
      error.message.to_s.should_not contain("access_denied")
      error.message.to_s.should_not contain("attacker-controlled-text")
      OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
        handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)
      end
    end
    transport.requests.should be_empty
  end

  it "uses only the consumed redirect and trusted session when callback fields are forged" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    transport.enqueue(OAuthHandlerSpecSupport.response)
    configuration = OAuthHandlerSpecSupport.configuration(
      redirect: "https://trusted.example/callback?encoded=a%2Bb%26c%3Dd"
    )
    handler = OAuthHandlerSpecSupport.handler(configuration, store, transport, clock)
    state = OAuthHandlerSpecSupport.issue(handler, "server-session")
    query = URI::Params.encode({
      "state"           => state,
      "code"            => "valid-code",
      "redirect_uri"    => "https://evil.example/callback",
      "session_binding" => "forged-session",
    })
    handler.authenticate_user(OAuthHandlerSpecSupport.callback(query),
      OAuthHandlerSpecSupport.secret("server-session"))

    form = URI::Params.parse(transport.requests.first.body || raise "Missing exchange body")
    form.to_h.keys.sort!.should eq(["client_id", "client_secret", "code", "redirect_uri"])
    form["redirect_uri"].should eq(configuration.redirect_uri.to_s)
    form["code"].should eq("valid-code")
  end

  it "uses the consumed attempt redirect when two handlers share a state store" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    transport.enqueue(OAuthHandlerSpecSupport.response)
    issuer = OAuthHandlerSpecSupport.handler(
      OAuthHandlerSpecSupport.configuration(redirect: "https://issuer.example/callback?flow=one"),
      store, OAuthStateSupport::RecordingTransport.new, clock)
    consumer = OAuthHandlerSpecSupport.handler(
      OAuthHandlerSpecSupport.configuration(redirect: "https://consumer.example/callback?flow=two"),
      store, transport, clock)

    state = OAuthHandlerSpecSupport.issue(issuer)
    consumer.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)
    form = URI::Params.parse(transport.requests.first.body || raise "Missing exchange body")
    form["redirect_uri"].should eq("https://issuer.example/callback?flow=one")
  end

  it "allows concurrent tabs and only one exchange for racing callbacks" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    3.times { transport.enqueue(OAuthHandlerSpecSupport.response) }
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)
    tab_one = OAuthHandlerSpecSupport.issue(handler)
    tab_two = OAuthHandlerSpecSupport.issue(handler)
    handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(tab_two), OAuthHandlerSpecSupport.secret)
    handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(tab_one), OAuthHandlerSpecSupport.secret)

    racing = OAuthHandlerSpecSupport.issue(handler)
    ready = Channel(Nil).new
    start = Channel(Nil).new
    results = Channel(Symbol).new(2)
    2.times do
      spawn do
        ready.send(nil)
        start.receive
        handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(racing), OAuthHandlerSpecSupport.secret)
        results.send(:success)
      rescue error : Slack::Auth::ContractError
        results.send(error.code.invalid_state? ? :invalid_state : :unexpected)
      rescue
        results.send(:unexpected)
      end
    end
    2.times { ready.receive }
    2.times { start.send(nil) }
    outcomes = [OAuthHandlerSpecSupport.bounded_result(results), OAuthHandlerSpecSupport.bounded_result(results)]
    outcomes.count(:success).should eq(1)
    outcomes.count(:invalid_state).should eq(1)
    transport.requests.size.should eq(3)
  end

  it "passes response status and retry metadata to the authoritative parser" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)

    state = OAuthHandlerSpecSupport.issue(handler)
    transport.enqueue(OAuthHandlerSpecSupport.response(status: 503))
    error = expect_raises(Slack::Auth::ResponseError) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)
    end
    error.code.invalid_response?.should be_true
    error.http_status.should eq(503)

    state = OAuthHandlerSpecSupport.issue(handler)
    transport.enqueue(Slack::Auth::TransportResponse.new(429,
      HTTP::Headers{"Retry-After" => "30"}, %({"ok":false,"error":"invalid_code"})))
    error = expect_raises(Slack::Auth::ResponseError) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(state), OAuthHandlerSpecSupport.secret)
    end
    error.code.reauthorization_required?.should be_true
    error.http_status.should eq(429)
    error.retry_after.should eq(30.seconds)
    error.slack_error.should eq("invalid_code")
  end

  it "normalizes bot, user, organization, and combined successes through AuthResponse.parse" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)
    %w[bot_workspace user_workspace bot_org_absent_team user_org_null_team combined_rotating].each do |fixture|
      transport.enqueue(OAuthHandlerSpecSupport.response(fixture))
      result = handler.authenticate_user(
        OAuthHandlerSpecSupport.encoded_callback(OAuthHandlerSpecSupport.issue(handler)),
        OAuthHandlerSpecSupport.secret
      )
      result.ok?.should be_true
      result.app_id.should_not be_empty
    end
    transport.requests.size.should eq(5)
  end

  it "keeps state spent after malformed responses and transport failures" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    transport = OAuthStateSupport::RecordingTransport.new
    handler = OAuthHandlerSpecSupport.handler(OAuthHandlerSpecSupport.configuration, store, transport, clock)

    malformed_state = OAuthHandlerSpecSupport.issue(handler)
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, "not-json"))
    expect_raises(Slack::Auth::ResponseError) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(malformed_state), OAuthHandlerSpecSupport.secret)
    end
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(malformed_state), OAuthHandlerSpecSupport.secret)
    end

    failed_state = OAuthHandlerSpecSupport.issue(handler)
    transport.fail_with(Slack::Auth::ContractError.new(:unknown_remote_outcome))
    OAuthHandlerSpecSupport.expect_contract_error(:unknown_remote_outcome) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(failed_state), OAuthHandlerSpecSupport.secret)
    end
    OAuthHandlerSpecSupport.expect_contract_error(:invalid_state) do
      handler.authenticate_user(OAuthHandlerSpecSupport.encoded_callback(failed_state), OAuthHandlerSpecSupport.secret)
    end
    transport.requests.size.should eq(2)
  end
end
