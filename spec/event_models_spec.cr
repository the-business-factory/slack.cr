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
