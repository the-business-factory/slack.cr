require "./spec_helper"

describe "Typed event field compatibility" do
  it "supports legacy revocation lookups alongside typed accessors without sharing JSON arrays" do
    envelope = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/credential_lifecycle/tokens_revoked.json"))
    event = envelope.event.should be_a(Slack::Events::TokensRevoked)

    legacy_ids : Array(JSON::Any) = event.tokens["oauth"].as_a
    legacy_ids.map(&.as_s).should eq(event.tokens.oauth)
    legacy_ids.first.as_s.should eq("U_ACTOR")
    event.tokens["bot"].as_a.should be_empty
    legacy_ids.clear
    event.tokens.oauth.should eq(["U_ACTOR"])
    event.tokens["oauth"].as_a.size.should eq(1)
  end

  it "supports legacy authorization lookups using Slack field names" do
    envelope = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/request_authorizer/event_connect_workspace.json"))

    legacy_team : String = envelope.authorizations.first["team_id"].as_s
    authorization = envelope.authorizations.first
    legacy_team.should eq("T_OWNER")
    legacy_team.should eq(authorization.team_id)
    authorization["user_id"].as_s.should eq(authorization.user_id)
    authorization["enterprise_id"].as_s.should eq(authorization.enterprise_id)
    authorization["is_bot"].as_bool.should be_true
    authorization["is_enterprise_install"].as_bool.should be_false
    authorization["is_enterprise_install"]?.should eq(JSON::Any.new(false))
  end

  it "distinguishes unknown keys from model defaults and nullable fields" do
    tokens = Slack::Events::TokensRevoked::Tokens.from_json(%({"unknown":["ignored"]}))
    tokens["oauth"].as_a.should be_empty
    tokens["bot"]?.should eq(JSON.parse("[]"))
    tokens["unknown"]?.should be_nil
    expect_raises(KeyError) { tokens["unknown"] }
    Slack::Events::TokensRevoked::Tokens.from_json(%({"oauth":null}))["oauth"].as_a.should be_empty

    authorization = Slack::Events::Authorization.from_json(%({"user_id":"U1","is_bot":false,"unknown":true}))
    authorization["team_id"].raw.should be_nil
    authorization["enterprise_id"].raw.should be_nil
    authorization["is_enterprise_install"]?.should eq(JSON::Any.new(nil))
    authorization["is_bot"].as_bool.should be_false
    authorization["unknown"]?.should be_nil
    expect_raises(KeyError) { authorization["unknown"] }
  end

  it "still rejects malformed token arrays and authorization fields" do
    [%({"oauth":"U1"}), %({"bot":[1]})].each do |json|
      expect_raises(JSON::SerializableError) { Slack::Events::TokensRevoked::Tokens.from_json(json) }
    end
    [
      %({"user_id":"U1","is_bot":"false"}),
      %({"user_id":1,"is_bot":false}),
      %({"user_id":"U1","is_bot":false,"team_id":1}),
      %({"user_id":"U1","is_bot":false,"enterprise_id":false}),
      %({"user_id":"U1","is_bot":false,"is_enterprise_install":"false"}),
    ].each do |json|
      expect_raises(JSON::SerializableError) { Slack::Events::Authorization.from_json(json) }
    end
  end
end

describe "Event envelope decoding" do
  it "keeps an unmapped event type as Unknown with its raw JSON" do
    body = File.read("spec/fixtures/events/unknown_event.json")
    envelope = Slack.from_json(body).should be_a(Slack::VerifiedEvent)
    event = envelope.event.should be_a(Slack::Events::Unknown)

    event.type.should eq("synthetic_future_event")
    event.team_id.should eq("T_EVENT")
    event.source_team_id.should eq("T_SOURCE")
    event.user_team_id.should be_nil
    event.raw["user"].as_s.should eq("U_ACTOR")
    event.raw["detail"].should eq(JSON.parse(%({"state":"ready","count":2})))
    JSON.parse(envelope.to_json)["event"].should eq(JSON.parse(body)["event"])
  end

  it "still decodes mapped event types and URL verification through the same entry" do
    envelope = Slack.from_json(File.read("spec/fixtures/events/app_uninstalled.json")).should be_a(Slack::VerifiedEvent)
    envelope.event.should be_a(Slack::Events::AppUninstalled)

    challenge = Slack.from_json(File.read("spec/fixtures/events/url_verification.json")).should be_a(Slack::UrlVerification)
    challenge.challenge.empty?.should be_false
  end

  it "rejects an inner event without a string type" do
    [%({}), %({"type":null}), %({"type":1}), %([]), %("app_mention")].each do |json|
      expect_raises(JSON::SerializableError) { Slack::Event.from_json(json) }
    end
    expect_raises(JSON::ParseException) { Slack::Event.from_json(%({"type":)) }
    expect_raises(JSON::SerializableError) { Slack::Events::Unknown.from_json(%({"team_id":"T1"})) }
    Slack::Events::Unknown.from_json(%({"type":"app_mention","team_id":7})).team_id.should be_nil
  end

  it "reads shared-channel and context envelope fields when present" do
    envelope = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/events/unknown_event.json"))
    envelope.is_ext_shared_channel.should be_true
    envelope.context_team_id.should eq("T_CONTEXT")
    envelope.context_enterprise_id.should eq("E1")
    envelope.event_context.should eq("4-synthetic-event-context")

    omitted = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/events/app_uninstalled.json"))
    omitted.is_ext_shared_channel.should be_nil
    omitted.context_team_id.should be_nil
    omitted.context_enterprise_id.should be_nil
    JSON.parse(omitted.to_json).as_h.keys.should_not contain("context_team_id")

    external = JSON.parse(File.read("spec/fixtures/events/app_uninstalled.json"))
    external.as_h["is_ext_shared_channel"] = JSON::Any.new(false)
    Slack::VerifiedEvent.from_json(external.to_json).is_ext_shared_channel.should be_false
  end
end

describe Slack::Events::Delivery do
  it "reads Slack retry headers without regard to header case" do
    delivery = Slack::Events::Delivery.from_headers(HTTP::Headers{
      "x-slack-retry-num"    => "2",
      "X-Slack-Retry-Reason" => "http_timeout",
    })
    delivery.retry_num.should eq(2)
    delivery.retry_reason.should eq("http_timeout")
    delivery.retry?.should be_true
  end

  it "treats a request without retry headers as the first delivery" do
    delivery = Slack::Events::Delivery.from_headers(HTTP::Headers{"Content-Type" => "application/json"})
    delivery.retry_num.should be_nil
    delivery.retry_reason.should be_nil
    delivery.retry?.should be_false
  end

  it "ignores a retry number that is not a positive integer" do
    %w[abc 0 -1 1.5].each do |value|
      Slack::Events::Delivery.from_headers(HTTP::Headers{"X-Slack-Retry-Num" => value}).retry_num.should be_nil
    end
  end
end
