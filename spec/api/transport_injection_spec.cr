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
  {"chat.postMessage", "views.open"}.each do |method_path|
    it "preserves checked #{method_path} envelopes with injected dispatch settings" do
      transport = AuthSupport::RecordingTransport.new
      transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":true})))
      limiter = OrderingLimiter.new
      configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/custom/"))
      request = if method_path == "chat.postMessage"
                  message = Slack::UI::Checked.message(fallback_text: "Details", &.divider)
                  Slack::Api::CheckedChatPostMessage.new(
                    token: "synthetic-checked-dispatch", channel: "C123", message: message,
                    configuration: configuration, transport: transport, limiter: limiter
                  )
                else
                  view = Slack::UI::Checked.display_modal(title: Slack::UI::Checked.plain("Details")) { |builder| builder.divider }
                  Slack::Api::CheckedViewsOpen.new(
                    token: "synthetic-checked-dispatch", trigger_id: "trigger", view: view,
                    configuration: configuration, transport: transport, limiter: limiter
                  )
                end

      expected_body = JSON.parse(request.to_json)
      request.result.status_code.should eq 200
      request.result.status_code.should eq 200
      limiter.passed?.should be_true
      transport.requests.size.should eq 1
      recorded = transport.requests.first
      recorded.uri.to_s.should eq "https://api.example.test/custom/#{method_path}"
      recorded.headers["Authorization"].should eq "Bearer synthetic-checked-dispatch"
      JSON.parse(recorded.body || fail("Expected checked envelope")).should eq expected_body
    end
  end

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
