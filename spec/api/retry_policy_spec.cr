require "../spec_helper"

# Answers each send with the next scripted response or transport error code.
private class ScriptedTransport < Slack::Auth::Transport
  alias Step = Slack::Auth::TransportResponse | Slack::Auth::ErrorCode

  getter requests = [] of Slack::Auth::TransportRequest
  @script = [] of Step

  def initialize(script : Enumerable(Step))
    script.each { |step| @script << step }
  end

  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    @requests << request
    step = @script.shift? || raise "no scripted response left"
    step.is_a?(Slack::Auth::ErrorCode) ? raise(Slack::Auth::ContractError.new(step)) : step
  end
end

private def rate_limited(retry_after : String? = "1") : Slack::Auth::TransportResponse
  headers = HTTP::Headers.new
  headers["Retry-After"] = retry_after if retry_after
  Slack::Auth::TransportResponse.new(429, headers, "")
end

private def deleted : Slack::Auth::TransportResponse
  Slack::Auth::TransportResponse.new(200, HTTP::Headers.new,
    %({"ok":true,"channel":"C1","ts":"1710000000.000001"}))
end

private def retrying_client(*script : Slack::Auth::TransportResponse | Slack::Auth::ErrorCode,
                            max_attempts : Int32 = 3, max_wait : Time::Span = 30.seconds)
  transport = ScriptedTransport.new(script)
  waits = [] of Time::Span
  policy = Slack::Api::RetryPolicy.new(max_attempts: max_attempts, max_wait: max_wait,
    sleep: ->(span : Time::Span) { waits << span; nil })
  client = Slack::Api::Client.new(token: "xoxb-synthetic-retry", transport: transport, retry: policy)
  {client, transport, waits}
end

private def delete_request : Slack::Api::ChatDelete
  Slack::Api::ChatDelete.new(channel: "C1", ts: "1710000000.000001")
end

private def expected_body : JSON::Any
  JSON.parse(%({"channel":"C1","ts":"1710000000.000001"}))
end

describe Slack::Api::RetryPolicy do
  it "waits Retry-After after HTTP 429 and sends the same request again" do
    client, transport, waits = retrying_client(rate_limited("1"), deleted)

    client.call(delete_request).ts.should eq "1710000000.000001"

    waits.should eq [1.second]
    transport.requests.size.should eq 2
    transport.requests.each do |sent|
      sent.uri.to_s.should eq "https://slack.com/api/chat.delete"
      sent.headers["Authorization"].should eq "Bearer xoxb-synthetic-retry"
      JSON.parse(sent.body.should_not(be_nil)).should eq expected_body
    end
  end

  it "raises the last RateLimited when max_attempts is reached" do
    client, transport, waits = retrying_client(rate_limited("1"), rate_limited("2"), deleted, max_attempts: 2)

    error = expect_raises(Slack::Api::RateLimited) { client.call(delete_request) }

    error.retry_after.should eq 2.seconds
    waits.should eq [1.second]
    transport.requests.size.should eq 2
  end

  it "does not wait when Retry-After is longer than max_wait or unusable" do
    [rate_limited("31"), rate_limited(nil), rate_limited("soon")].each do |response|
      client, transport, waits = retrying_client(response, deleted)

      expect_raises(Slack::Api::RateLimited) { client.call(delete_request) }

      waits.should be_empty
      transport.requests.size.should eq 1
    end
  end

  it "sends again without waiting after a transport failure that sent nothing" do
    client, transport, waits = retrying_client(Slack::Auth::ErrorCode::TransportFailure, deleted)

    client.call(delete_request).channel.should eq "C1"

    waits.should be_empty
    transport.requests.size.should eq 2
  end

  it "never sends again when Slack may have received the request" do
    uncertain = Slack::Auth::ErrorCode::UnknownRemoteOutcome
    server_error = Slack::Auth::TransportResponse.new(503, HTTP::Headers.new, "")
    not_ok = Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":false,"error":"internal_error"}))

    client, transport, _waits = retrying_client(uncertain, deleted)
    expect_raises(Slack::Auth::ContractError, "UnknownRemoteOutcome") { client.call(delete_request) }
    transport.requests.size.should eq 1

    {server_error, not_ok}.each do |response|
      client, transport, _waits = retrying_client(response, deleted)
      expect_raises(Slack::Api::Error) { client.call(delete_request) }
      transport.requests.size.should eq 1
    end
  end

  it "rejects fewer than one attempt and a negative max_wait" do
    expect_raises(ArgumentError, "max_attempts") { Slack::Api::RetryPolicy.new(max_attempts: 0, max_wait: 1.second) }
    expect_raises(ArgumentError, "max_wait") { Slack::Api::RetryPolicy.new(max_attempts: 2, max_wait: -1.second) }
  end
end
