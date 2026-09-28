require "../spec_helper"
require "../support/auth/fakes"
require "../support/request_authorizer/fakes"

private def auth_context(configuration_uri : String = "https://api.example.test/api/")
  store = RequestAuthorizerSupport::Store.new(RequestAuthorizerSupport::Clock.new)
  transport = RequestAuthorizerSupport::Transport.new
  key = RequestAuthorizerSupport.workspace_key("T1", "E1")
  record = RequestAuthorizerSupport.seed(store, key)
  query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
  context = Slack::Auth::RequestContext.new(query, store.acquire(query), store, transport,
    Slack::Auth::APIConfiguration.new(URI.parse(configuration_uri)))
  {context, transport, store, record}
end

describe Slack::Api::AuthTest do
  success = <<-JSON
    {
      "ok": true,
      "url": "https://workspace-one.slack.com/",
      "team": "Workspace One",
      "user": "request-authorizer",
      "team_id": "T1",
      "user_id": "U_ACTOR",
      "bot_id": "B1",
      "enterprise_id": "E1",
      "is_enterprise_install": false
    }
    JSON

  it "reads identity fields, including null organization fields" do
    transport = AuthSupport::RecordingTransport.new
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, success))
    transport.enqueue(Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, <<-JSON))
      {"ok":true,"url":"https://enterprise.slack.com/","user":"org-bot","team_id":null,"team":null,
       "user_id":"U_ORG_BOT","enterprise_id":"E_ORG","is_enterprise_install":true}
      JSON
    client = Slack::Api::Client.new(token: "xoxb-synthetic", transport: transport)

    workspace = client.call(Slack::Api::AuthTest.new)
    workspace.user_id.should eq "U_ACTOR"
    workspace.bot_id.should eq "B1"
    workspace.enterprise_id.should eq "E1"
    organization = client.call(Slack::Api::AuthTest.new)
    organization.team_id.should be_nil
    organization.enterprise_id.should eq "E_ORG"
    organization.is_enterprise_install.should be_true
  end

  it "posts an empty form to the configured endpoint with the fenced bearer header" do
    context, transport, _store, _record = auth_context("https://gov.example/slack/api/")
    transport.enqueue(success)

    context.auth_test.user_id.should eq "U_ACTOR"

    request = transport.requests.first
    request.method.should eq "POST"
    request.uri.to_s.should eq "https://gov.example/slack/api/auth.test"
    request.headers["Authorization"].should eq "Bearer actor-token"
    request.headers["Content-Type"].should eq "application/x-www-form-urlencoded"
    request.body.to_s.should be_empty
  end

  it "maps Slack failures to allowlisted auth errors without remote text" do
    context, transport, _store, _record = auth_context
    {
      {Slack::Auth::ErrorCode::ReauthorizationRequired, %({"ok":false,"error":"token_revoked","detail":"canary"})},
      {Slack::Auth::ErrorCode::ReauthorizationRequired, %({"ok":false,"error":"invalid_auth"})},
      {Slack::Auth::ErrorCode::ReauthorizationRequired, %({"ok":false,"error":"account_inactive"})},
      {Slack::Auth::ErrorCode::InvalidResponse, %({"ok":false,"error":"missing_scope"})},
      {Slack::Auth::ErrorCode::InvalidResponse, %({"ok":false,"error":"canary-untrusted-code"})},
      {Slack::Auth::ErrorCode::InvalidResponse, %({"ok":true})},
      {Slack::Auth::ErrorCode::InvalidResponse, %({"ok":true,"user_id":17})},
      {Slack::Auth::ErrorCode::InvalidResponse, "{canary-response"},
    }.each do |code, body|
      transport.enqueue(body)
      error = expect_raises(Slack::Auth::ContractError) { context.auth_test }
      error.should_not be_a(Slack::Auth::RequestAuthorizationError)
      error.code.should eq code
      error.http_status.should eq 200
      error.message.to_s.should_not contain("canary")
    end
  end

  it "maps rate limiting to an invalid response with the retry delay" do
    context, transport, _store, _record = auth_context
    transport.enqueue("canary-body", 429, HTTP::Headers{"Retry-After" => "7"})

    error = expect_raises(Slack::Auth::ContractError) { context.auth_test }

    error.code.should eq Slack::Auth::ErrorCode::InvalidResponse
    error.http_status.should eq 429
    error.retry_after.should eq 7.seconds
    error.message.to_s.should_not contain("canary")
  end

  it "validates selected user, workspace, enterprise, and organization identity without reselection" do
    clock = RequestAuthorizerSupport::Clock.new
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/"))

    workspace_store = RequestAuthorizerSupport::Store.new(clock)
    workspace_transport = RequestAuthorizerSupport::Transport.new
    workspace_key = RequestAuthorizerSupport.workspace_key("T1", "E1")
    RequestAuthorizerSupport.seed(workspace_store, workspace_key)
    user_query = Slack::Auth::InstallationQuery.new(workspace_key, Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
    workspace = Slack::Auth::RequestContext.new(user_query, workspace_store.acquire(user_query),
      workspace_store, workspace_transport, configuration)
    workspace_transport.enqueue(success.sub(%("user_id": "U_ACTOR"), %("user_id": "U_OTHER")))
    expect_raises(Slack::Auth::RequestAuthorizationError) { workspace.auth_test }.reason.should eq(:identity_mismatch)
    workspace_transport.enqueue(success.sub(%("team_id": "T1"), %("team_id": "T_OTHER")))
    expect_raises(Slack::Auth::RequestAuthorizationError) { workspace.auth_test }.reason.should eq(:identity_mismatch)

    org_store = RequestAuthorizerSupport::Store.new(clock)
    org_transport = RequestAuthorizerSupport::Transport.new
    org_key = RequestAuthorizerSupport.org_key
    RequestAuthorizerSupport.seed(org_store, org_key, bot_subject: "U_ORG_BOT")
    org_query = Slack::Auth::InstallationQuery.new(org_key, Slack::Auth::GrantKey.new(:bot))
    org_context = Slack::Auth::RequestContext.new(org_query, org_store.acquire(org_query),
      org_store, org_transport, configuration)
    org_transport.enqueue(<<-JSON)
      {
        "ok": true,
        "user_id": "U_ORG_BOT",
        "team_id": null,
        "enterprise_id": "E_ORG",
        "is_enterprise_install": true
      }
      JSON
    org_context.auth_test.enterprise_id.should eq("E_ORG")
    org_transport.enqueue(%({"ok":true,"user_id":"U_OTHER_BOT","enterprise_id":"E_ORG","is_enterprise_install":true}))
    expect_raises(Slack::Auth::RequestAuthorizationError) { org_context.auth_test }.reason.should eq(:identity_mismatch)
    org_transport.enqueue(%({"ok":true,"user_id":"U_ORG_BOT","enterprise_id":"E_ORG","is_enterprise_install":false}))
    expect_raises(Slack::Auth::RequestAuthorizationError) { org_context.auth_test }.reason.should eq(:identity_mismatch)
    org_transport.enqueue(%({"ok":true,"user_id":"U_ORG_BOT","enterprise_id":"E_OTHER"}))
    expect_raises(Slack::Auth::RequestAuthorizationError) { org_context.auth_test }.reason.should eq(:identity_mismatch)
  end

  it "validates the authenticated bot user from the selected grant revision" do
    clock = RequestAuthorizerSupport::Clock.new
    configuration = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/"))
    key = RequestAuthorizerSupport.workspace_key
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, key, bot_subject: "U_EXPECTED_BOT")
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    context = Slack::Auth::RequestContext.new(query, store.acquire(query), store, transport, configuration)

    transport.enqueue(%({"ok":true,"user_id":"U_EXPECTED_BOT","bot_id":"B1","team_id":"T1"}))
    context.auth_test.user_id.should eq("U_EXPECTED_BOT")

    transport.enqueue(%({"ok":true,"user_id":"U_UNRELATED_HUMAN","team_id":"T1"}))
    expect_raises(Slack::Auth::RequestAuthorizationError) { context.auth_test }.reason.should eq(:identity_mismatch)
    transport.enqueue(%({"ok":true,"user_id":"U_DIFFERENT_BOT","bot_id":"B2","team_id":"T1"}))
    expect_raises(Slack::Auth::RequestAuthorizationError) { context.auth_test }.reason.should eq(:identity_mismatch)
  end

  it "rejects direct context construction after the selected grant revision changes" do
    clock = RequestAuthorizerSupport::Clock.new
    key = RequestAuthorizerSupport.workspace_key
    store = RequestAuthorizerSupport::Store.new(clock)
    record = RequestAuthorizerSupport.seed(store, key, bot_subject: "U_EXPECTED_BOT")
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    reference = store.acquire(query)
    updated = store.store(key, Slack::Auth::InstallationPatch.new(users: {
      "U_OTHER" => RequestAuthorizerSupport.grant("U_OTHER", "other-user-token"),
    }), record.version)
    context = Slack::Auth::RequestContext.new(query, reference, store, RequestAuthorizerSupport::Transport.new,
      Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/")))
    context.reference.should eq(reference)

    store.store(key, Slack::Auth::InstallationPatch.new(
      bot: RequestAuthorizerSupport.grant("U_NEW_BOT", "replacement-token")), updated.version)

    expect_raises(Slack::Auth::ContractError, "Authentication failure: Conflict") do
      Slack::Auth::RequestContext.new(query, reference, store, RequestAuthorizerSupport::Transport.new,
        Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/")))
    end
  end
end
