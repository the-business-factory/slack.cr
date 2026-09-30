require "../spec_helper"
require "../../src/slack/testing"

private class ManualClock < Slack::Auth::Clock
  property now : Time = Time.utc(2026, 9, 29)
end

# Authored from https://docs.slack.dev/reference/methods/chat.postMessage.
private POSTED = %({"ok":true,"channel":"C-SYNTHETIC","ts":"1789232400.000100",) +
                 %("message":{"type":"message","text":"hi","user":"U-BOT","ts":"1789232400.000100"}})

private def replying(body : String) : Slack::Testing::RecordingTransport
  Slack::Testing::RecordingTransport.new { |_request| Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, body) }
end

describe Slack::Api::Client do
  it "paces every attempt through the rate limits it is given" do
    waits = [] of Time::Span
    limits = Slack::Api::RateLimits.new(ManualClock.new, ->(span : Time::Span) { waits << span; nil })
    transport = replying(POSTED)
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport, rate_limits: limits)
    tier = Slack::Api::RateLimitTier::Special

    (tier.burst + 1).times { client.call(Slack::Api::ChatPostMessage.new(channel: "C-SYNTHETIC", text: "hi")) }

    waits.should eq [tier.interval]
    transport.requests.size.should eq tier.burst + 1
  end

  # The only sleeping example: a default client waits one Tier 4 interval (0.6 s).
  it "paces by default" do
    transport = replying(%({"ok":true,"user":{"id":"U-SYNTHETIC"}}))
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport)
    tier = Slack::Api::RateLimitTier::Tier4

    elapsed = Time.measure do
      (tier.burst + 1).times { client.call("users.info", {user: "U-SYNTHETIC"}, tier: tier) }
    end

    elapsed.should be >= tier.interval * 0.9
    transport.requests.size.should eq tier.burst + 1
  end
end
