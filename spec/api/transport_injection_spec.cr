require "../spec_helper"
require "../support/auth/fakes"

private class OrderingLimiter
  include RateLimiter::LimiterLike

  getter? passed : Bool = false

  def get : RateLimiter::Token
    @passed = true
    RateLimiter::Token.new
  end

  def get(max_wait : Time::Span) : RateLimiter::Token | RateLimiter::Timeout
    get
  end
end

private class OrderingTransport < Slack::Auth::Transport
  getter? executed_after_limit : Bool = false

  def initialize(@limiter : OrderingLimiter)
  end

  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    @executed_after_limit = @limiter.passed?
    Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/team-info-success.json"))
  end
end

describe "API transport injection" do
  it "uses the configured host, prefix, encoded query, and bearer header" do
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      File.read("spec/fixtures/api/conversations-info-C032TLM43GA.json")))
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.gov.example/custom/api"))
    channel = "C032TLM43GA"

    Slack::Api::ConversationsInfo.new(
      token: "synthetic-token",
      channel: channel,
      configuration: configuration,
      transport: transport
    ).call.should be_a(Slack::Models::PublicChannel)

    recorded = transport.requests.first
    recorded.method.should eq("GET")
    recorded.uri.to_s.should eq("https://api.gov.example/custom/api/conversations.info?channel=C032TLM43GA")
    recorded.headers["Authorization"].should eq("Bearer synthetic-token")
    recorded.body.should be_nil
    recorded.uri.to_s.should_not contain("slack.com")
  end

  it "waits for the limiter before transport execution" do
    limiter = OrderingLimiter.new
    transport = OrderingTransport.new(limiter)
    endpoint = Slack::Api::TeamInfo.new(
      token: "ordering-token",
      configuration: Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/")),
      transport: transport
    )

    Slack::ApiClient.new(endpoint, limiter: limiter, transport: transport).get
    transport.executed_after_limit?.should be_true
  end

  it "passes transport and configuration through the modal convenience method" do
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
      %({"ok":true,"view":{}})))
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.gov.example/custom/"))

    Slack::Helpers::Modal.open(
      access_token: "synthetic-token",
      blocks: [] of Slack::TypeAliases::ModalBlock,
      close: "Close",
      submit: "Submit",
      trigger_id: "trigger",
      title: "Title",
      configuration: configuration,
      transport: transport
    ).should be_a(Slack::Models::ViewsOpen)

    recorded = transport.requests.first
    recorded.uri.to_s.should eq("https://api.gov.example/custom/views.open")
    recorded.headers["Authorization"].should eq("Bearer synthetic-token")
    recorded.body.to_s.should_not contain("synthetic-token")
    recorded.body.to_s.should_not contain("api.gov.example")
  end
end
