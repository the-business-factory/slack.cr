require "../spec_helper"

# A generic envelope that shares VerifiedEvent's field list. This is a spec
# probe for a later typed decoder, not shipped code.
private struct Envelope(E)
  include JSON::Serializable
  include Slack::InitializerMacros

  Slack::Events::EnvelopeFields.declare(E)
end

private def event_callback_fixtures : Array(String)
  Dir.glob("spec/fixtures/events/**/*.json").sort.select do |path|
    JSON.parse(File.read(path))["type"]?.try(&.as_s?) == "event_callback"
  end
end

describe Slack::Events::EnvelopeFields do
  it "keeps every envelope field of every event fixture through VerifiedEvent" do
    fixtures = event_callback_fixtures
    fixtures.size.should be > 50

    fixtures.each do |path|
      source = JSON.parse(File.read(path)).as_h
      output = JSON.parse(Slack::VerifiedEvent.from_json(source.to_json).to_json).as_h

      # A missing authorizations list decodes as empty and emits as [].
      (output.keys - ["authorizations"]).sort.should eq((source.keys - ["authorizations"]).sort), path
      source.each do |key, value|
        next if key.in?("event", "authorizations")
        output[key].should eq(value), "#{path}: #{key}"
      end
    end
  end

  it "declares the same fields on a generic envelope with a typed event" do
    body = <<-JSON
      {
        "token": "synthetic-legacy-token",
        "team_id": "T-SYNTHETIC",
        "context_team_id": "T-CONTEXT",
        "context_enterprise_id": "E-CONTEXT",
        "api_app_id": "A-SYNTHETIC",
        "event": {
          "type": "app_mention",
          "user": "U-HUMAN",
          "text": "<@U-BOT> deploy",
          "ts": "1789232400.000100",
          "channel": "C-SYNTHETIC",
          "event_ts": "1789232400.000100"
        },
        "type": "event_callback",
        "event_id": "Ev-ENVELOPE-1",
        "event_time": 1789232400,
        "event_context": "4-synthetic-event-context",
        "is_ext_shared_channel": true,
        "authorizations": [
          {"team_id": "T-SYNTHETIC", "user_id": "U-BOT", "is_bot": true, "is_enterprise_install": false}
        ]
      }
      JSON

    envelope = Envelope(Slack::Events::AppMentioned).from_json(body)
    envelope.event.text.should eq("<@U-BOT> deploy")
    envelope.event_time.should eq(Time.unix(1789232400))
    envelope.context_enterprise_id.should eq("E-CONTEXT")
    envelope.authorizations.first.user_id.should eq("U-BOT")

    envelope.to_json.should eq(Slack::VerifiedEvent.from_json(body).to_json)
  end
end
