require "../spec_helper"
require "../support/request_authorizer/fakes"

private def extraction_failure(reason : Symbol, &)
  error = expect_raises(Slack::Auth::RequestAuthorizationError) { yield }
  error.reason.should eq(reason)
end

describe Slack::Auth::QueryExtractor do
  extractor = Slack::Auth::QueryExtractor.new("A1")
  bot = Slack::Auth::GrantKey.new(:bot)

  it "uses the authorization owner while preserving distinct Connect metadata" do
    payload = Slack::VerifiedEvent.from_json(RequestAuthorizerSupport.fixture("event_connect_workspace.json"))
    query = extractor.extract(payload, bot)

    query.owner.should eq(RequestAuthorizerSupport.workspace_key("T_OWNER", "E1"))
    query.actor_user_id.should eq("U_EXTERNAL_ACTOR")
    query.visible_team_id.should eq("T_VISIBLE")
    payload.event.team_id.should eq("T_EVENT")
    payload.event.source_team_id.should eq("T_SOURCE")
    payload.event.user_team_id.should eq("T_ACTOR")
    payload.authorizations.first.user_id.should eq("U_INSTALLER")
  end

  it "removes a contextual team from an organization owner" do
    payload = Slack::VerifiedEvent.from_json(RequestAuthorizerSupport.fixture("event_org_context.json"))
    query = extractor.extract(payload, bot)
    query.owner.should eq(RequestAuthorizerSupport.org_key)
    query.owner.team_id.should be_nil
    query.visible_team_id.should be_nil
  end

  it "accepts repeated authorization entries for one owner and rejects distinct owners" do
    object = JSON.parse(RequestAuthorizerSupport.fixture("event_connect_workspace.json"))
    authorizations = object["authorizations"].as_a
    authorizations << authorizations.first
    extractor.extract(Slack::VerifiedEvent.from_json(object.to_json), bot).owner.team_id.should eq("T_OWNER")

    second = JSON.parse(authorizations.first.to_json)
    second.as_h["team_id"] = JSON::Any.new("T_OTHER")
    authorizations << second
    payload = Slack::VerifiedEvent.from_json(object.to_json)
    extraction_failure(:ambiguous_owner) { extractor.extract(payload, bot) }

    selected = RequestAuthorizerSupport.workspace_key("T_OTHER", "E1")
    extractor.extract(payload, bot, selected).owner.should eq(selected)
    extraction_failure(:owner_not_authorized) do
      extractor.extract(payload, bot, RequestAuthorizerSupport.workspace_key("T_MISSING", "E1"))
    end
  end

  it "accepts only an unambiguous legacy workspace authorization" do
    object = JSON.parse(RequestAuthorizerSupport.fixture("event_connect_workspace.json"))
    authorization = object["authorizations"][0]
    authorization.as_h.delete("is_enterprise_install")
    authorization.as_h["enterprise_id"] = JSON::Any.new(nil)
    extractor.extract(Slack::VerifiedEvent.from_json(object.to_json), bot).owner.kind.workspace?.should be_true

    authorization.as_h["enterprise_id"] = JSON::Any.new("E1")
    extraction_failure(:invalid_install_kind) do
      extractor.extract(Slack::VerifiedEvent.from_json(object.to_json), bot)
    end
  end

  it "extracts workspace and organization slash commands without actor fallback" do
    workspace = Slack::Commands::Parser.parse(RequestAuthorizerSupport.command_body(enterprise_id: "E1"))
    query = extractor.extract(workspace, Slack::Auth::GrantKey.new(:user, "U_INSTALLER"))
    query.owner.should eq(RequestAuthorizerSupport.workspace_key("T1", "E1"))
    query.actor_user_id.should eq("U_ACTOR")
    query.grant.user_id.should eq("U_INSTALLER")

    org = Slack::Commands::Parser.parse(RequestAuthorizerSupport.command_body(
      team_id: nil, enterprise_id: "E_ORG", enterprise_install: "true"))
    extractor.extract(org, bot).owner.should eq(RequestAuthorizerSupport.org_key)
  end

  it "rejects duplicate routing fields and malformed command booleans" do
    body = RequestAuthorizerSupport.command_body
    extraction_failure(:duplicate_routing_field) { Slack::Commands::Parser.parse("#{body}&team_id=T2") }
    extraction_failure(:invalid_install_kind) do
      Slack::Commands::Parser.parse(RequestAuthorizerSupport.command_body(enterprise_install: "yes"))
    end
  end

  {
    "interaction_global_shortcut.json" => {"Slack::Interactions::Shortcut", :workspace},
    "interaction_message_action.json"  => {"Slack::Interactions::MessageAction", :organization},
    "interaction_block_message.json"   => {"Slack::Interactions::BlockAction", :workspace},
    "interaction_block_view.json"      => {"Slack::Interactions::BlockAction", :workspace},
    "interaction_view_submission.json" => {"Slack::Interactions::ViewSubmission", :workspace},
    "interaction_view_closed.json"     => {"Slack::Interactions::ViewClosed", :workspace},
  }.each do |fixture, expectation|
    it "extracts ownership from #{fixture}" do
      interaction = Slack::Interaction.from_json(RequestAuthorizerSupport.fixture(fixture))
      interaction.class.to_s.should eq(expectation[0])
      query = extractor.extract(interaction, bot)
      query.owner.kind.to_s.downcase.should eq(expectation[1].to_s)
      query.actor_user_id.should eq("U_ACTOR")
    end
  end

  it "uses view installation ownership without attaching visible enterprise evidence" do
    %w[interaction_block_view.json interaction_view_submission.json interaction_view_closed.json].each do |fixture|
      interaction = Slack::Interaction.from_json(RequestAuthorizerSupport.fixture(fixture))
      query = extractor.extract(interaction, bot)
      query.owner.should eq(RequestAuthorizerSupport.workspace_key("T_OWNER"))
      query.visible_team_id.should eq("T_VISIBLE")
    end

    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_view_submission.json"))
    object.as_h["is_enterprise_install"] = JSON::Any.new(true)
    object.as_h["enterprise"] = JSON.parse(%({"id":"E_ORG"}))
    object["team"].as_h["enterprise_id"] = JSON::Any.new("E_ORG")
    organization_view = Slack::Interaction.from_json(object.to_json)
    extractor.extract(organization_view, bot).owner.should eq(RequestAuthorizerSupport.org_key)

    object.as_h["is_enterprise_install"] = JSON::Any.new(false)
    object.as_h["enterprise"] = JSON.parse(%({"id":"E_VISIBLE"}))
    object["team"].as_h["enterprise_id"] = JSON::Any.new("E_VISIBLE")
    ambiguous = Slack::Interaction.from_json(object.to_json)
    extraction_failure(:ambiguous_owner) { extractor.extract(ambiguous, bot) }
  end

  it "binds app-less shortcuts to the configured trusted route and preserves explicit mismatch checks" do
    global = Slack::Interaction.from_json(RequestAuthorizerSupport.fixture("interaction_global_shortcut.json"))
    extractor.extract(global, bot).owner.should eq(RequestAuthorizerSupport.workspace_key("T1", "E1"))

    message = Slack::Interaction.from_json(RequestAuthorizerSupport.fixture("interaction_message_action.json"))
    extractor.extract(message, bot).owner.should eq(RequestAuthorizerSupport.org_key)

    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_global_shortcut.json"))
    object.as_h["api_app_id"] = JSON::Any.new("A_OTHER")
    extraction_failure(:app_mismatch) do
      extractor.extract(Slack::Interaction.from_json(object.to_json), bot)
    end
  end

  it "reconciles exact workspace enterprise evidence and rejects conflicts or an unknown kind" do
    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_block_message.json"))
    object["team"].as_h["enterprise_id"] = JSON::Any.new("E1")
    object.as_h.delete("enterprise")
    nested = Slack::Interaction.from_json(object.to_json)
    extractor.extract(nested, bot).owner.should eq(RequestAuthorizerSupport.workspace_key("T1", "E1"))

    object.as_h["enterprise"] = JSON.parse(%({"id":"E1"}))
    agreeing = Slack::Interaction.from_json(object.to_json)
    extractor.extract(agreeing, bot).owner.should eq(RequestAuthorizerSupport.workspace_key("T1", "E1"))

    object.as_h["enterprise"] = JSON.parse(%({"id":"E_OTHER"}))
    extraction_failure(:conflicting_owner) do
      extractor.extract(Slack::Interaction.from_json(object.to_json), bot)
    end

    object.as_h.delete("enterprise")
    object.as_h.delete("is_enterprise_install")
    extraction_failure(:invalid_install_kind) do
      extractor.extract(Slack::Interaction.from_json(object.to_json), bot)
    end
  end

  it "rejects missing or malformed view installation ownership" do
    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_view_submission.json"))
    object["view"].as_h["app_installed_team_id"] = JSON::Any.new("")
    extraction_failure(:empty_id) do
      extractor.extract(Slack::Interaction.from_json(object.to_json), bot)
    end

    object["view"].as_h.delete("app_installed_team_id")
    object.as_h["team"] = JSON::Any.new(nil)
    extraction_failure(:missing_owner) do
      extractor.extract(Slack::Interaction.from_json(object.to_json), bot)
    end
  end

  it "rejects missing, empty, mismatched, and wrongly typed routing evidence" do
    interaction = JSON.parse(RequestAuthorizerSupport.fixture("interaction_global_shortcut.json"))
    interaction.as_h.delete("is_enterprise_install")
    extraction_failure(:invalid_install_kind) { extractor.extract(Slack::Interaction.from_json(interaction.to_json), bot) }
    interaction.as_h["is_enterprise_install"] = JSON::Any.new(false)
    interaction.as_h["api_app_id"] = JSON::Any.new("A2")
    extraction_failure(:app_mismatch) { extractor.extract(Slack::Interaction.from_json(interaction.to_json), bot) }
    interaction.as_h["api_app_id"] = JSON::Any.new("")
    extraction_failure(:missing_app) { extractor.extract(Slack::Interaction.from_json(interaction.to_json), bot) }
    expect_raises(JSON::SerializableError) do
      Slack::Interaction.from_json(interaction.to_json.sub(%("is_enterprise_install":false), %("is_enterprise_install":"false")))
    end
  end
end
