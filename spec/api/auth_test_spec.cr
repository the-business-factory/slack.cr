require "../spec_helper"
require "../support/request_authorizer/fakes"

private def auth_test_error(reason : Symbol, &)
  error = expect_raises(Slack::Api::AuthTestError) { yield }
  error.reason.should eq(reason)
  error
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

  it "parses String and IO success bodies once with nullable organization fields" do
    string_result = Slack::Api::AuthTest.parse(success)
    io_result = Slack::Api::AuthTest.parse(IO::Memory.new(success))
    string_result.should eq(io_result)
    string_result.user_id.should eq("U_ACTOR")
    string_result.bot_id.should eq("B1")
    string_result.enterprise_id.should eq("E1")

    org = Slack::Api::AuthTest.parse(<<-JSON)
      {
        "ok": true,
        "url": "https://enterprise.slack.com/",
        "user": "org-bot",
        "team_id": null,
        "team": null,
        "user_id": "U_ORG_BOT",
        "enterprise_id": "E_ORG",
        "is_enterprise_install": true
      }
      JSON
    org.team_id.should be_nil
    org.team.should be_nil
    org.enterprise_id.should eq("E_ORG")
  end

  it "rejects malformed success data without retaining response content" do
    [
      %({"ok":true}),
      %({"ok":true,"user_id":17}),
      %({"ok":true,"user_id":"U1","team_id":false}),
      %({"ok":true,"user_id":"U1","is_enterprise_install":"true"}),
      %({"ok":"true","user_id":"U1"}),
      "{canary-response",
    ].each do |body|
      error = auth_test_error(:invalid_response) { Slack::Api::AuthTest.parse(body) }
      error.message.to_s.should_not contain("canary")
      error.inspect.should_not contain("canary")
    end
    closed = IO::Memory.new(success)
    closed.close
    auth_test_error(:invalid_response) { Slack::Api::AuthTest.parse(closed) }
  end

  it "maps allowlisted API failures without exposing arbitrary remote errors" do
    reauthorization = auth_test_error(:reauthorization_required) do
      Slack::Api::AuthTest.parse(%({"ok":false,"error":"token_revoked","detail":"canary-secret"}))
    end
    reauthorization.code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
    reauthorization.message.to_s.should_not contain("canary")

    auth_test_error(:missing_scope) do
      Slack::Api::AuthTest.parse(%({"ok":false,"error":"missing_scope"}))
    end
    unknown = auth_test_error(:api_error) do
      Slack::Api::AuthTest.parse(%({"ok":false,"error":"canary-untrusted-code"}))
    end
    unknown.message.to_s.should_not contain("canary")
  end

  it "maps rate limiting and server failures without parsing unsafe bodies" do
    limited = auth_test_error(:rate_limited) do
      Slack::Api::AuthTest.parse("canary-body", 429, HTTP::Headers{"Retry-After" => "7"})
    end
    limited.http_status.should eq(429)
    limited.retry_after.should eq(7.seconds)
    limited.message.to_s.should_not contain("canary")

    server = auth_test_error(:server_error) { Slack::Api::AuthTest.parse("<h1>canary</h1>", 503) }
    server.http_status.should eq(503)
    auth_test_error(:http_error) { Slack::Api::AuthTest.parse("canary", 404) }
  end

  it "posts to the configured endpoint with a fenced bearer header and no token body" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key("T1", "E1")
    RequestAuthorizerSupport.seed(store, key)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
    context = Slack::Auth::RequestContext.new(query, store.acquire(query), store, transport,
      Slack::Auth::APIConfiguration.new(URI.parse("https://gov.example/slack/api/")))
    transport.enqueue(success)

    result = context.auth_test
    result.user_id.should eq("U_ACTOR")
    request = transport.requests.first
    request.method.should eq("POST")
    request.uri.to_s.should eq("https://gov.example/slack/api/auth.test")
    request.headers["Authorization"].should eq("Bearer actor-token")
    request.body.should be_nil
    request.headers["Content-Type"].should eq("application/x-www-form-urlencoded")
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
