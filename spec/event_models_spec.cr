require "./spec_helper"

describe "Typed event fields" do
  it "decodes revoked token IDs by kind" do
    envelope = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/credential_lifecycle/tokens_revoked.json"))
    event = envelope.event.should be_a(Slack::Events::TokensRevoked)

    event.tokens.oauth.should eq(["U_ACTOR"])
    event.tokens.bot.should be_empty
  end

  it "decodes authorization fields using Slack field names" do
    envelope = Slack::VerifiedEvent.from_json(File.read("spec/fixtures/request_authorizer/event_connect_workspace.json"))
    authorization = envelope.authorizations.first

    authorization.team_id.should eq("T_OWNER")
    authorization.user_id.should eq("U_INSTALLER")
    authorization.enterprise_id.should eq("E1")
    authorization.bot?.should be_true
    authorization.enterprise_install.should be_false
  end

  it "treats omitted and null optional fields as empty or nil" do
    Slack::Events::TokensRevoked::Tokens.from_json(%({"unknown":["ignored"]})).oauth.should be_empty
    Slack::Events::TokensRevoked::Tokens.from_json(%({"oauth":null})).oauth.should be_empty

    authorization = Slack::Events::Authorization.from_json(%({"user_id":"U1","is_bot":false,"unknown":true}))
    authorization.team_id.should be_nil
    authorization.enterprise_id.should be_nil
    authorization.enterprise_install.should be_nil
    authorization.bot?.should be_false
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
