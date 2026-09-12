require "../spec_helper"
require "../support/request_authorizer/fakes"

module RequestAuthorizerSpec
  CONFIGURATION  = Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/slack/api/"))
  SIGNING_SECRET = "synthetic-request-authorizer-secret"

  def self.request(body : String, clock : RequestAuthorizerSupport::Clock,
                   signature : String? = nil, timestamp : Int64? = nil) : HTTP::Request
    seconds = timestamp || clock.now.to_unix
    timestamp_text = seconds.to_s
    headers = HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp_text,
      "X-Slack-Signature"         => signature || Slack::Webhooks::Signature.new(timestamp_text, body).compute,
    }
    HTTP::Request.new("POST", "/slack", headers, body)
  end

  def self.authorizer(store : RequestAuthorizerSupport::Store,
                      transport : RequestAuthorizerSupport::Transport,
                      clock : RequestAuthorizerSupport::Clock,
                      configuration : Slack::Auth::APIConfiguration = CONFIGURATION) : Slack::Auth::RequestAuthorizer
    Slack::Auth::RequestAuthorizer.new("A1", store, transport, configuration, -> { clock.now })
  end

  def self.event_request(clock : RequestAuthorizerSupport::Clock) : HTTP::Request
    request(RequestAuthorizerSupport.fixture("event_connect_workspace.json"), clock)
  end

  def self.command_request(clock : RequestAuthorizerSupport::Clock) : HTTP::Request
    request(RequestAuthorizerSupport.command_body, clock)
  end

  def self.interaction_request(clock : RequestAuthorizerSupport::Clock,
                               fixture : String = "interaction_global_shortcut.json") : HTTP::Request
    body = URI::Params.encode({"payload" => RequestAuthorizerSupport.fixture(fixture)})
    request(body, clock)
  end

  def self.view(interaction : Slack::Interaction) : Slack::Interactions::View?
    case interaction
    when Slack::Interactions::BlockAction
      interaction.view
    when Slack::Interactions::ViewSubmission
      interaction.view
    when Slack::Interactions::ViewClosed
      interaction.view
    end
  end

  def self.failure(code : Slack::Auth::ErrorCode, &)
    expect_raises(Slack::Auth::ContractError) { yield }.code.should eq(code)
  end
end

describe Slack::Auth::RequestAuthorizer do
  around_each do |example|
    secret = Slack.settings.signing_secret
    version = Slack.settings.signing_secret_version
    limit = Slack.settings.webhook_delivery_time_limit
    begin
      Slack.configure do |settings|
        settings.signing_secret = RequestAuthorizerSpec::SIGNING_SECRET
        settings.signing_secret_version = "v0"
        settings.webhook_delivery_time_limit = 5.minutes
      end
      example.run
    ensure
      Slack.configure do |settings|
        settings.signing_secret = secret
        settings.signing_secret_version = version
        settings.webhook_delivery_time_limit = limit
      end
    end
  end

  it "verifies and authorizes each HTTP category before store access" do
    clock = RequestAuthorizerSupport::Clock.new
    transport = RequestAuthorizerSupport::Transport.new

    event_store = RequestAuthorizerSupport::Store.new(clock)
    RequestAuthorizerSupport.seed(event_store, RequestAuthorizerSupport.workspace_key("T_OWNER", "E1"))
    RequestAuthorizerSpec.authorizer(event_store, transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
      .query.owner.team_id.should eq("T_OWNER")

    command_store = RequestAuthorizerSupport::Store.new(clock)
    RequestAuthorizerSupport.seed(command_store, RequestAuthorizerSupport.workspace_key)
    RequestAuthorizerSpec.authorizer(command_store, transport, clock)
      .authorize_command(RequestAuthorizerSpec.command_request(clock), Slack::Auth::GrantKey.new(:bot))
      .query.owner.team_id.should eq("T1")

    interaction_store = RequestAuthorizerSupport::Store.new(clock)
    RequestAuthorizerSupport.seed(interaction_store, RequestAuthorizerSupport.workspace_key("T1", "E1"))
    RequestAuthorizerSpec.authorizer(interaction_store, transport, clock)
      .authorize_interaction(RequestAuthorizerSpec.interaction_request(clock), Slack::Auth::GrantKey.new(:bot))
      .query.owner.team_id.should eq("T1")

    {event_store, command_store, interaction_store}.each(&.acquire_count.should(eq(1)))
    transport.requests.should be_empty
  end

  it "rejects invalid and stale signatures for all categories without store or API calls" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)
    grant = Slack::Auth::GrantKey.new(:bot)

    event_body = RequestAuthorizerSupport.fixture("event_connect_workspace.json")
    command_body = RequestAuthorizerSupport.command_body
    interaction_body = URI::Params.encode({
      "payload" => RequestAuthorizerSupport.fixture("interaction_global_shortcut.json"),
    })
    operations = [
      {event_body, ->(request : HTTP::Request) { authorizer.authorize_event(request, grant) }},
      {command_body, ->(request : HTTP::Request) { authorizer.authorize_command(request, grant) }},
      {interaction_body, ->(request : HTTP::Request) { authorizer.authorize_interaction(request, grant) }},
    ]
    operations.each do |body, authorize|
      expect_raises(Slack::Errors::SignatureMismatch) do
        authorize.call(RequestAuthorizerSpec.request(body, clock, "v0=#{"0" * 64}"))
      end
      expect_raises(Slack::Errors::ReplayAttack) do
        authorize.call(RequestAuthorizerSpec.request(body, clock, timestamp: clock.now.to_unix - 301))
      end
      missing = RequestAuthorizerSpec.request(body, clock)
      missing.headers.delete("X-Slack-Signature")
      expect_raises(Slack::Errors::InvalidWebhookRequest) { authorize.call(missing) }
    end

    store.acquire_count.should eq(0)
    store.dispatch_count.should eq(0)
    store.fetch_count.should eq(0)
    transport.requests.should be_empty
  end

  it "normalizes signed malformed payloads and rejects duplicate interaction payloads before acquire" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)
    grant = Slack::Auth::GrantKey.new(:bot)

    [
      -> { authorizer.authorize_event(RequestAuthorizerSpec.request("{}", clock), grant) },
      -> { authorizer.authorize_command(RequestAuthorizerSpec.request("api_app_id=A1", clock), grant) },
      -> { authorizer.authorize_interaction(RequestAuthorizerSpec.request("payload={}&payload={}", clock), grant) },
    ].each do |operation|
      expect_raises(Slack::Auth::RequestAuthorizationError) { operation.call }.reason.should eq(:invalid_payload)
    end
    store.acquire_count.should eq(0)
    transport.requests.should be_empty
  end

  it "fails closed on signed routing errors and keeps URL verification outside authorization" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)
    grant = Slack::Auth::GrantKey.new(:bot)

    event = JSON.parse(RequestAuthorizerSupport.fixture("event_connect_workspace.json"))
    event.as_h["authorizations"] = JSON::Any.new([] of JSON::Any)
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_event(RequestAuthorizerSpec.request(event.to_json, clock), grant)
    end.reason.should eq(:missing_owner)

    command = RequestAuthorizerSupport.command_body(app_id: "A_OTHER")
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_command(RequestAuthorizerSpec.request(command, clock), grant)
    end.reason.should eq(:app_mismatch)

    interaction = RequestAuthorizerSupport.fixture("interaction_global_shortcut.json")
      .sub(%("is_enterprise_install": false), %("is_enterprise_install": "false"))
    interaction_form = URI::Params.encode({"payload" => interaction})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(interaction_form, clock), grant)
    end.reason.should eq(:invalid_payload)

    shortcut = JSON.parse(RequestAuthorizerSupport.fixture("interaction_global_shortcut.json"))
    shortcut.as_h["api_app_id"] = JSON::Any.new("A_OTHER")
    shortcut_form = URI::Params.encode({"payload" => shortcut.to_json})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(shortcut_form, clock), grant)
    end.reason.should eq(:app_mismatch)

    conflicting = JSON.parse(RequestAuthorizerSupport.fixture("interaction_block_message.json"))
    conflicting["team"].as_h["enterprise_id"] = JSON::Any.new("E1")
    conflicting.as_h["enterprise"] = JSON.parse(%({"id":"E_OTHER"}))
    conflicting_form = URI::Params.encode({"payload" => conflicting.to_json})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(conflicting_form, clock), grant)
    end.reason.should eq(:conflicting_owner)

    missing_app = JSON.parse(RequestAuthorizerSupport.fixture("interaction_block_message.json"))
    missing_app.as_h.delete("api_app_id")
    missing_app_form = URI::Params.encode({"payload" => missing_app.to_json})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(missing_app_form, clock), grant)
    end.reason.should eq(:missing_app)

    empty_view_owner = JSON.parse(RequestAuthorizerSupport.fixture("interaction_view_submission.json"))
    empty_view_owner["view"].as_h["app_installed_team_id"] = JSON::Any.new("")
    empty_view_form = URI::Params.encode({"payload" => empty_view_owner.to_json})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(empty_view_form, clock), grant)
    end.reason.should eq(:empty_id)

    %w[interaction_block_view.json interaction_view_submission.json interaction_view_closed.json].each do |fixture|
      malformed_view_owner = JSON.parse(RequestAuthorizerSupport.fixture(fixture))
      malformed_view_owner["view"].as_h["app_installed_team_id"] = JSON::Any.new(true)
      malformed_view_form = URI::Params.encode({"payload" => malformed_view_owner.to_json})
      expect_raises(Slack::Auth::RequestAuthorizationError) do
        authorizer.authorize_interaction(RequestAuthorizerSpec.request(malformed_view_form, clock), grant)
      end.reason.should eq(:invalid_payload)
    end

    challenge = File.read("spec/fixtures/events/url_verification.json")
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_event(RequestAuthorizerSpec.request(challenge, clock), grant)
    end.reason.should eq(:invalid_payload)

    store.acquire_count.should eq(0)
    store.fetch_count.should eq(0)
    transport.requests.should be_empty
  end

  it "selects the requested grant exactly even when actor and installer differ" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key("T_OWNER", "E1")
    RequestAuthorizerSupport.seed(store, key)
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)

    bot = authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    bot.dispatch("POST", "chat.postMessage")
    transport.requests.last.headers["Authorization"].should eq("Bearer bot-token")

    user = authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock),
      Slack::Auth::GrantKey.new(:user, "U_INSTALLER"))
    user.dispatch("POST", "chat.postMessage")
    transport.requests.last.headers["Authorization"].should eq("Bearer installer-token")

    actor = authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock),
      Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
    actor.dispatch("POST", "chat.postMessage")
    transport.requests.last.headers["Authorization"].should eq("Bearer actor-token")
    RequestAuthorizerSpec.failure(:missing_grant) do
      authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock),
        Slack::Auth::GrantKey.new(:user, "U_EXTERNAL_ACTOR"))
    end
  end

  it "retains signed view content and dispatches with the installed team's token" do
    clock = RequestAuthorizerSupport::Clock.new(Time.utc)
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T_OWNER"), "owner-bot-token")
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T_VISIBLE"), "visible-bot-token")
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)

    %w[interaction_block_view.json interaction_view_submission.json interaction_view_closed.json].each do |fixture|
      object = JSON.parse(RequestAuthorizerSupport.fixture(fixture))
      view = object["view"].as_h
      view["callback_id"] = JSON::Any.new("save-form")
      view["private_metadata"] = JSON::Any.new("synthetic-workflow-123")
      view["hash"] = JSON::Any.new("synthetic-view-version")
      view["state"] = JSON.parse(%({"values":{"description":{"input":{"type":"plain_text_input","value":"submitted text"}}}}))
      view["future_content"] = JSON.parse(%({"retained":true}))
      body = URI::Params.encode({"payload" => object.to_json})

      interaction = Slack.process_interaction(RequestAuthorizerSpec.request(body, clock))
      parsed_view = RequestAuthorizerSpec.view(interaction).should_not be_nil
      parsed_view.app_installed_team_id.should eq("T_OWNER")
      JSON.parse(parsed_view.to_json).should eq(object["view"])
      parsed_view["id"].as_s.should eq("V1")
      parsed_view["callback_id"].as_s.should eq("save-form")
      parsed_view["private_metadata"].as_s.should eq("synthetic-workflow-123")
      parsed_view["hash"].as_s.should eq("synthetic-view-version")
      parsed_view.dig("state", "values", "description", "input", "value").as_s.should eq("submitted text")
      parsed_view.dig("future_content", "retained").as_bool.should be_true

      context = authorizer.authorize_interaction(RequestAuthorizerSpec.request(body, clock),
        Slack::Auth::GrantKey.new(:bot))
      context.query.owner.should eq(RequestAuthorizerSupport.workspace_key("T_OWNER"))
      context.query.visible_team_id.should eq("T_VISIBLE")
      context.dispatch("POST", "chat.postMessage")
      transport.requests.last.headers["Authorization"].should eq("Bearer owner-bot-token")
    end
  end

  it "rejects unrelated enterprise evidence for a cross-workspace view before store access" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T_OWNER"), "owner-token")
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T_OWNER", "E_VISIBLE"),
      "enterprise-qualified-token")
    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_view_submission.json"))
    object.as_h["enterprise"] = JSON.parse(%({"id":"E_VISIBLE"}))
    object["team"].as_h["enterprise_id"] = JSON::Any.new("E_VISIBLE")
    body = URI::Params.encode({"payload" => object.to_json})

    error = expect_raises(Slack::Auth::RequestAuthorizationError) do
      RequestAuthorizerSpec.authorizer(store, transport, clock).authorize_interaction(
        RequestAuthorizerSpec.request(body, clock), Slack::Auth::GrantKey.new(:bot))
    end
    error.reason.should eq(:ambiguous_owner)
    store.acquire_count.should eq(0)
    store.fetch_count.should eq(0)
    store.dispatch_count.should eq(0)
    transport.requests.should be_empty
  end

  it "authorizes signed workspace and organization shortcuts without api_app_id" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T1", "E1"),
      "workspace-bot-token")
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.org_key, "organization-bot-token")
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)

    {
      "interaction_global_shortcut.json" => "Bearer workspace-bot-token",
      "interaction_message_action.json"  => "Bearer organization-bot-token",
    }.each do |fixture, authorization|
      context = authorizer.authorize_interaction(RequestAuthorizerSpec.interaction_request(clock, fixture),
        Slack::Auth::GrantKey.new(:bot))
      context.dispatch("POST", "chat.postMessage")
      transport.requests.last.headers["Authorization"].should eq(authorization)
    end
  end

  it "uses nested enterprise evidence to select one exact installed workspace" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T1"), "unqualified-token")
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T1", "E1"), "qualified-token")
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)
    object = JSON.parse(RequestAuthorizerSupport.fixture("interaction_block_message.json"))
    object["team"].as_h["enterprise_id"] = JSON::Any.new("E1")
    body = URI::Params.encode({"payload" => object.to_json})

    context = authorizer.authorize_interaction(RequestAuthorizerSpec.request(body, clock),
      Slack::Auth::GrantKey.new(:bot))
    context.dispatch("POST", "chat.postMessage")
    context.query.owner.should eq(RequestAuthorizerSupport.workspace_key("T1", "E1"))
    transport.requests.last.headers["Authorization"].should eq("Bearer qualified-token")

    object.as_h.delete("is_enterprise_install")
    missing_kind_body = URI::Params.encode({"payload" => object.to_json})
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      authorizer.authorize_interaction(RequestAuthorizerSpec.request(missing_kind_body, clock),
        Slack::Auth::GrantKey.new(:bot))
    end.reason.should eq(:invalid_install_kind)
    store.acquire_count.should eq(1)
    transport.requests.size.should eq(1)
  end

  it "does not scan another tenant or hide store acquisition failures" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key("T_OTHER", "E1"))
    authorizer = RequestAuthorizerSpec.authorizer(store, transport, clock)

    RequestAuthorizerSpec.failure(:missing_installation) do
      authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    end
    store.acquire_failure = Slack::Auth::ErrorCode::PersistenceFailure
    RequestAuthorizerSpec.failure(:persistence_failure) do
      authorizer.authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    end
    transport.requests.should be_empty
  end
end

describe Slack::Auth::RequestContext do
  it "checks the credential fence for every send and preserves unrelated grant updates" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    transport = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key("T_OWNER", "E1")
    record = RequestAuthorizerSupport.seed(store, key)
    context = RequestAuthorizerSpec.authorizer(store, transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))

    context.dispatch("POST", "chat.postMessage")
    updated = store.store(key, Slack::Auth::InstallationPatch.new(users: {
      "U_ACTOR" => RequestAuthorizerSupport.grant("U_ACTOR", "updated-user-token"),
    }), record.version)
    context.dispatch("POST", "chat.postMessage")
    store.dispatch_count.should eq(2)
    transport.requests.size.should eq(2)

    store.store(key, Slack::Auth::InstallationPatch.new(bot: RequestAuthorizerSupport.grant("B1", "replacement")), updated.version)
    RequestAuthorizerSpec.failure(:conflict) { context.dispatch("POST", "chat.postMessage") }
    transport.requests.size.should eq(2)
  end

  it "blocks expiry, deletion, dispatched refresh, and adapter dispatch failures" do
    clock = RequestAuthorizerSupport::Clock.new
    key = RequestAuthorizerSupport.workspace_key("T_OWNER", "E1")

    expired_store = RequestAuthorizerSupport::Store.new(clock)
    expired_store.store(key, Slack::Auth::InstallationPatch.new(
      bot: RequestAuthorizerSupport.grant("B1", "expired", clock.now)), nil)
    expired_transport = RequestAuthorizerSupport::Transport.new
    expired = RequestAuthorizerSpec.authorizer(expired_store, expired_transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    RequestAuthorizerSpec.failure(:reauthorization_required) { expired.dispatch("POST", "auth.test") }

    store = RequestAuthorizerSupport::Store.new(clock)
    record = RequestAuthorizerSupport.seed(store, key)
    transport = RequestAuthorizerSupport::Transport.new
    context = RequestAuthorizerSpec.authorizer(store, transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    store.delete(key, record.version)
    RequestAuthorizerSpec.failure(:missing_installation) { context.dispatch("POST", "auth.test") }
    tombstone = store.fetch(key).should_not be_nil
    store.store(key, Slack::Auth::InstallationPatch.new(
      bot: RequestAuthorizerSupport.grant("B1", "reinstalled")), tombstone.version)
    RequestAuthorizerSpec.failure(:conflict) { context.dispatch("POST", "auth.test") }

    refresh_store = RequestAuthorizerSupport::Store.new(clock)
    refresh_store.store(key, Slack::Auth::InstallationPatch.new(bot: Slack::Auth::Grant.new(
      "B1", Slack::Auth::Secret.new("access"), [] of String,
      refresh_token: Slack::Auth::Secret.new("refresh"))), nil)
    refresh_transport = RequestAuthorizerSupport::Transport.new
    refresh_context = RequestAuthorizerSpec.authorizer(refresh_store, refresh_transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    lease = refresh_store.claim_refresh(refresh_context.reference, 1.minute)
    refresh_store.mark_refresh_dispatched(lease)
    RequestAuthorizerSpec.failure(:refresh_busy) { refresh_context.dispatch("POST", "auth.test") }
    refresh_store.fail_refresh(lease, Slack::Auth::RefreshFailure::UnknownRemoteOutcome)
    RequestAuthorizerSpec.failure(:unknown_remote_outcome) { refresh_context.dispatch("POST", "auth.test") }

    failure_store = RequestAuthorizerSupport::Store.new(clock)
    RequestAuthorizerSupport.seed(failure_store, key)
    failure_store.dispatch_failure = Slack::Auth::ErrorCode::PersistenceFailure
    failure_transport = RequestAuthorizerSupport::Transport.new
    failure_context = RequestAuthorizerSpec.authorizer(failure_store, failure_transport, clock)
      .authorize_event(RequestAuthorizerSpec.event_request(clock), Slack::Auth::GrantKey.new(:bot))
    RequestAuthorizerSpec.failure(:persistence_failure) { failure_context.dispatch("POST", "auth.test") }

    {expired_transport, transport, refresh_transport, failure_transport}.each(&.requests.should(be_empty))
  end

  it "restricts origin and path before store access and overwrites wrapper authorization" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    delegate = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    reference = store.acquire(query)
    context = Slack::Auth::RequestContext.new(query, reference, store, delegate, RequestAuthorizerSpec::CONFIGURATION)

    [
      "https://foreign.example/slack/api/auth.test",
      "https://api.example.test/other/auth.test",
      "https://api.example.test/slack/api/%2e%2e/other",
      "https://api.example.test:444/slack/api/auth.test",
    ].each do |destination|
      expect_raises(Slack::Auth::RequestAuthorizationError) do
        context.transport.execute(Slack::Auth::TransportRequest.new("POST", URI.parse(destination)))
      end.reason.should eq(:unsafe_destination)
    end
    store.dispatch_count.should eq(0)

    request = Slack::Auth::TransportRequest.new("POST", URI.parse("https://api.example.test/slack/api/auth.test"),
      HTTP::Headers{"Authorization" => "Bearer cached-wrapper-token"})
    context.transport.execute(request)
    delegate.requests.last.headers["Authorization"].should eq("Bearer bot-token")
    delegate.requests.last.headers.to_s.should_not contain("cached-wrapper-token")

    delegate.enqueue("redirect", 302, HTTP::Headers{"Location" => "https://foreign.example/token"})
    response = context.dispatch("POST", "auth.test")
    response.status.should eq(302)
    delegate.requests.size.should eq(2)
  end

  it "snapshots mutable configured and request URIs before credential dispatch" do
    clock = RequestAuthorizerSupport::Clock.new
    store = RequestAuthorizerSupport::Store.new(clock)
    delegate = RequestAuthorizerSupport::Transport.new
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    reference = store.acquire(query)
    configured_uri = URI.parse("https://api.example.test/slack/api/")
    context = Slack::Auth::RequestContext.new(query, reference, store, delegate,
      Slack::Auth::APIConfiguration.new(configured_uri))
    configured_uri.host = "foreign.example"

    request_uri = URI.parse("https://api.example.test/slack/api/auth.test")
    context.transport.execute(Slack::Auth::TransportRequest.new("POST", request_uri))
    request_uri.host = "foreign.example"
    delegate.requests.last.uri.host.should eq("api.example.test")
    context.transport.configuration.base_uri.host = "also-foreign.example"
    context.dispatch("POST", "auth.test")
    delegate.requests.last.uri.host.should eq("api.example.test")

    authorizer_uri = URI.parse("https://api.example.test/slack/api/")
    authorizer = Slack::Auth::RequestAuthorizer.new("A1", store, delegate,
      Slack::Auth::APIConfiguration.new(authorizer_uri))
    authorizer_uri.host = "foreign.example"
    trusted = Slack::Commands::Parser.parse(RequestAuthorizerSupport.command_body)
    authorizer.authorize_trusted(trusted, Slack::Auth::GrantKey.new(:bot)).dispatch("POST", "auth.test")
    delegate.requests.last.uri.host.should eq("api.example.test")
  end
end
