require "../spec_helper"
require "../../src/slack/testing"
require "../support/app/signed_request"

# Authored from https://docs.slack.dev/reference/events/app_mention.
private def app_mention(index : Int32) : String
  ts = "1789232400.#{index.to_s.rjust(6, '0')}"
  <<-JSON
    {"token":"synthetic-legacy-token","team_id":"T-SYNTHETIC","api_app_id":"A-SYNTHETIC",
     "event":{"type":"app_mention","user":"U-MENTIONER","text":"<@U-BOT> status #{index}",
              "ts":"#{ts}","channel":"C-SYNTHETIC","event_ts":"#{ts}"},
     "type":"event_callback","event_id":"Ev-MENTION-#{index}","event_time":1789232400,
     "authorizations":[{"team_id":"T-SYNTHETIC","user_id":"U-BOT","is_bot":true,"is_enterprise_install":false}]}
    JSON
end

# Authored from https://docs.slack.dev/reference/methods/chat.postMessage.
private POSTED = %({"ok":true,"channel":"C-SYNTHETIC","ts":"1789232401.000100",) +
                 %("message":{"type":"message","text":"On it","user":"U-BOT","ts":"1789232401.000100"}})

describe Slack::Testing::InstantRateLimits do
  it "lets an app post more than the chat.postMessage burst without waiting" do
    deliveries = Slack::Api::RateLimitTier::Special.burst + 1
    transport = Slack::Testing::RecordingTransport.new do |_request|
      Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, POSTED)
    end
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport,
      rate_limits: Slack::Testing::InstantRateLimits.new)
    app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
    posted = Channel(String).new(deliveries)
    app.event(Slack::Events::AppMentioned) do |ctx|
      ctx.say("On it")
      posted.send(ctx.event.ts)
    end
    receiver = Slack::App::HttpReceiver.new(app, AppSupport::VERIFIER)

    elapsed = Time.measure do
      deliveries.times do |index|
        AppSupport.run(receiver, AppSupport.json(app_mention(index + 1))).status.should eq 200
      end
      deliveries.times do
        select
        when posted.receive
        when timeout(1.second) then fail "a listener did not post within one second"
        end
      end
    end

    elapsed.should be < 1.second
    transport.requests.count(&.uri.path.==("/api/chat.postMessage")).should eq deliveries
  end
end
