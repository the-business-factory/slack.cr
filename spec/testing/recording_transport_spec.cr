require "../spec_helper"
require "../../src/slack/testing"

private def recording_client(transport : Slack::Testing::RecordingTransport) : Slack::Api::Client
  Slack::Api::Client.new(token: "xoxb-synthetic-recording", transport: transport)
end

describe Slack::Testing::RecordingTransport do
  it "records each request a client sends and answers from the queue in order" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true}))
    transport.respond(%({"ok":false,"error":"message_not_found"}))
    client = recording_client(transport)

    client.call(Slack::Api::ReactionsAdd.new(channel: "C123", name: "eyes", timestamp: "1710000000.000100"))
    error = expect_raises(Slack::Api::Error) do
      client.call(Slack::Api::ChatDelete.new(channel: "C123", ts: "1710000000.000100"))
    end

    error.code.should eq "message_not_found"
    first, second = transport.requests
    first.method.should eq "POST"
    first.uri.to_s.should eq "https://slack.com/api/reactions.add"
    first.headers["Authorization"].should eq "Bearer xoxb-synthetic-recording"
    JSON.parse(first.body.to_s).should eq JSON.parse(%({"channel":"C123","name":"eyes","timestamp":"1710000000.000100"}))
    second.uri.path.should eq "/api/chat.delete"
  end

  it "returns the queued status and headers" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":false,"error":"ratelimited"}), status: 429, headers: HTTP::Headers{"Retry-After" => "30"})

    error = expect_raises(Slack::Api::RateLimited) do
      recording_client(transport).call(Slack::Api::TeamInfo.new)
    end

    error.retry_after.should eq 30.seconds
  end

  it "answers from the block when the queue is empty" do
    transport = Slack::Testing::RecordingTransport.new do |request|
      Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":true,"url":"#{request.uri.path}"}))
    end
    transport.respond(%({"ok":true,"url":"queued"}))
    client = recording_client(transport)

    client.call("auth.test")["url"].should eq "queued"
    client.call("auth.test")["url"].should eq "/api/auth.test"
    transport.requests.size.should eq 2
  end

  it "records and rejects a request that has no response, without its query or credentials" do
    transport = Slack::Testing::RecordingTransport.new
    request = Slack::Auth::TransportRequest.new("POST", URI.parse("https://slack.com/api/oauth.v2.access?code=synthetic-code"),
      HTTP::Headers{"Authorization" => "Bearer xoxb-synthetic-hidden"}, "client_secret=synthetic-secret")

    error = expect_raises(Slack::Testing::UnstubbedRequest, "No response for POST /api/oauth.v2.access") do
      transport.execute(request)
    end

    message = error.message.to_s
    {"synthetic-code", "xoxb-synthetic-hidden", "synthetic-secret"}.each { |secret| message.should_not contain(secret) }
    transport.requests.size.should eq 1
  end

  it "returns a copy of the recorded requests" do
    transport = Slack::Testing::RecordingTransport.new
    transport.respond(%({"ok":true}))
    recording_client(transport).call("auth.test")

    transport.requests.clear
    transport.requests.size.should eq 1
  end
end
