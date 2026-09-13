require "../spec_helper"
require "../support/auth/fakes"

private class TrackingLimiter
  include RateLimiter::LimiterLike

  getter calls : Int32 = 0

  def initialize(@events : Array(String)? = nil)
  end

  def get : RateLimiter::Token
    @calls += 1
    @events.try &.<<("limiter")
    RateLimiter::Token.new
  end

  def get(max_wait : Time::Span) : RateLimiter::Token | RateLimiter::Timeout
    get
  end
end

private class CredentialInjectingTransport < Slack::Auth::Transport
  getter credential_reads : Int32 = 0

  def initialize(@delegate : Slack::Auth::Transport, @events : Array(String))
  end

  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise "Endpoint supplied an authorization header" if request.headers["Authorization"]?

    @credential_reads += 1
    @events << "credential"
    headers = request.headers.dup
    headers["Authorization"] = "Bearer current-credential"
    @events << "delegate"
    @delegate.execute(Slack::Auth::TransportRequest.new(
      request.method,
      request.uri,
      headers,
      request.body
    ))
  end
end

describe "tokenless API endpoints" do
  it "constructs endpoints with required and optional parameters without a bearer header" do
    limiter = TrackingLimiter.new
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/conversations-history-success.json")))

    Slack::Api::ConversationsHistory.tokenless(
      channel: "C123",
      cursor: "next cursor",
      inclusive: true,
      transport: transport,
      limiter: limiter
    ).call.should be_a(Slack::Models::ConversationsHistory)

    request = transport.requests.first
    request.uri.query_params["channel"].should eq("C123")
    request.uri.query_params["cursor"].should eq("next cursor")
    request.uri.query_params["inclusive"].should eq("true")
    request.headers["Authorization"]?.should be_nil
    limiter.calls.should eq(1)
  end

  it "supports tokenless reactions and keeps injected dependencies out of JSON" do
    limiter = TrackingLimiter.new
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/reactions-add-success.json")))
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/custom/"))

    endpoint = Slack::Api::ReactionsAdd.tokenless(
      channel: "C123",
      name: "wave",
      timestamp: "123.456",
      configuration: configuration,
      transport: transport,
      limiter: limiter
    )
    serialized = endpoint.to_json
    serialized.should_not contain("api.example.test")
    serialized.should_not contain("configuration")
    serialized.should_not contain("limiter")
    serialized.should_not contain("token")
    serialized.should_not contain("transport")

    endpoint.call.should be_a(Slack::Models::DefaultResponse)
    request = transport.requests.first
    request.uri.to_s.should eq("https://api.example.test/custom/reactions.add")
    request.headers["Authorization"]?.should be_nil
    JSON.parse(request.body.to_s)["name"].as_s.should eq("wave")
  end

  it "waits before a scoped transport reads and injects the current credential" do
    events = [] of String
    limiter = TrackingLimiter.new(events)
    delegate = AuthSupport::RecordingTransport.new
    delegate.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/team-info-success.json")))
    transport = CredentialInjectingTransport.new(delegate, events)

    Slack::Api::TeamInfo.tokenless(
      transport: transport,
      limiter: limiter
    ).call.should be_a(Slack::Models::Team)

    events.should eq(["limiter", "credential", "delegate"])
    transport.credential_reads.should eq(1)
    delegate.requests.first.headers["Authorization"].should eq("Bearer current-credential")
  end

  it "rejects missing tokenless dependencies and blank raw tokens without dispatch" do
    limiter = TrackingLimiter.new
    transport = AuthSupport::RecordingTransport.new

    expect_raises(ArgumentError, "explicit transport") do
      Slack::Api::TeamInfo.new(token: nil, limiter: limiter).call
    end
    expect_raises(ArgumentError, "explicit limiter") do
      Slack::Api::TeamInfo.new(token: nil, transport: transport).call
    end
    expect_raises(ArgumentError, "must not be blank") do
      Slack::Api::TeamInfo.new(token: " \t", transport: transport, limiter: limiter).call
    end

    limiter.calls.should eq(0)
    transport.requests.should be_empty
  end

  it "honors explicit limiters in raw-token and tokenless modes despite cached entries" do
    raw_token = "explicit-limiter-token"
    raw_endpoint = Slack::Api::TeamInfo.new(raw_token)
    raw_cache_key = "#{raw_token}:#{raw_endpoint.class}"
    tokenless_cache_key = ":#{raw_endpoint.class}"
    cached_limiter = TrackingLimiter.new
    direct_limiter = TrackingLimiter.new
    tokenless_limiter = TrackingLimiter.new
    transport = AuthSupport::RecordingTransport.new
    2.times do
      transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
        File.read("spec/fixtures/api/team-info-success.json")))
    end

    Slack::ApiClient.limiters[raw_cache_key] = cached_limiter
    Slack::ApiClient.limiters[tokenless_cache_key] = cached_limiter
    begin
      Slack::Api::TeamInfo.new(
        raw_token,
        transport: transport,
        limiter: direct_limiter
      ).call
      Slack::Api::TeamInfo.tokenless(
        transport: transport,
        limiter: tokenless_limiter
      ).call
    ensure
      Slack::ApiClient.limiters.delete(raw_cache_key)
      Slack::ApiClient.limiters.delete(tokenless_cache_key)
    end

    cached_limiter.calls.should eq(0)
    direct_limiter.calls.should eq(1)
    tokenless_limiter.calls.should eq(1)
  end

  it "preserves required and optional positional raw-token constructors" do
    positional = Slack::Api::ConversationsInfo.new("positional-token", "C123")
    history = Slack::Api::ConversationsHistory.new(
      "history-token",
      "C456",
      "cursor-value"
    )
    message = Slack::Api::ChatPostMessage.new(
      "message-token",
      "C789",
      nil,
      nil,
      "positional message"
    )
    named = Slack::Api::ReactionsAdd.new(
      token: "named-token",
      channel: "C123",
      name: "wave",
      timestamp: "123.456"
    )

    positional.token.should eq("positional-token")
    positional.channel.should eq("C123")
    history.cursor.should eq("cursor-value")
    message.text.should eq("positional message")
    named.token.should eq("named-token")
    named.name.should eq("wave")
  end

  it "supports tokenless message and modal convenience paths" do
    limiter = TrackingLimiter.new
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/chat-post-success-section.json")))
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      %({"ok":true,"view":{}})))
    section = Slack::UI::Components::TextSection.render(text: "Tokenless", markdown: true)

    Slack::Api::ChatPostMessage.post_blocks(
      blocks: [section],
      channel: "C123",
      transport: transport,
      limiter: limiter
    ).should be_a(Slack::Models::Chat::PostMessage)
    Slack::Helpers::Modal.open(
      blocks: [] of Slack::TypeAliases::ModalBlock,
      close: "Close",
      submit: "Submit",
      trigger_id: "trigger",
      title: "Title",
      transport: transport,
      limiter: limiter
    ).should be_a(Slack::Models::ViewsOpen)

    transport.requests.size.should eq(2)
    transport.requests.each do |request|
      request.headers["Authorization"]?.should be_nil
    end
    limiter.calls.should eq(2)
  end
end
