require "../spec_helper"
require "../../src/slack/auth/credential_lifecycle"
require "../support/credential_lifecycle/store"

module CredentialLifecycleSpec
  def self.body(name : String = "tokens_revoked") : String
    File.read("spec/fixtures/credential_lifecycle/#{name}.json")
  end

  def self.request(body : String, now : Time) : HTTP::Request
    timestamp = now.to_unix.to_s
    signature = Slack::Webhooks::Signature.new(timestamp, body).compute
    HTTP::Request.new("POST", "/events", HTTP::Headers{
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature"         => signature,
    }, body)
  end

  def self.prepare(service : Slack::Auth::CredentialLifecycle, clock : RequestAuthorizerSupport::Clock,
                   name : String = "tokens_revoked") : Slack::Auth::PreparedLifecycleDelivery
    service.prepare(request(body(name), clock.now), RequestAuthorizerSupport.workspace_key)
  end

  def self.context(store : Slack::Auth::InstallationStore, transport : Slack::Auth::Transport,
                   grant : Slack::Auth::GrantKey) : Slack::Auth::RequestContext
    query = Slack::Auth::InstallationQuery.new(RequestAuthorizerSupport.workspace_key, grant)
    Slack::Auth::RequestContext.new(query, store.acquire(query), store, transport,
      Slack::Auth::APIConfiguration.new(URI.parse("https://api.example.test/api/")))
  end

  def self.refreshable(subject : String, token : String = "synthetic-access") : Slack::Auth::Grant
    Slack::Auth::Grant.new(subject, Slack::Auth::Secret.new(token), [] of String,
      refresh_token: Slack::Auth::Secret.new("synthetic-refresh"))
  end
end

describe Slack::Auth::CredentialLifecycle do
  around_each do |example|
    secret = Slack.settings.signing_secret
    begin
      Slack.settings.signing_secret = "synthetic-lifecycle-signing-secret"
      example.run
    ensure
      Slack.settings.signing_secret = secret
    end
  end

  it "parses documented user ID lists without requiring event_ts or both token kinds" do
    event = Slack::VerifiedEvent.from_json(CredentialLifecycleSpec.body("bot_revoked")).event
      .should be_a(Slack::Events::TokensRevoked)
    event.tokens.bot.should eq(["U_BOT"])
    event.tokens.oauth.should be_empty
    event.event_ts.should be_nil
    uninstall = Slack::VerifiedEvent.from_json(CredentialLifecycleSpec.body("app_uninstalled")).event
      .should be_a(Slack::Events::AppUninstalled)
    uninstall.event_ts.should be_nil
  end

  it "removes one user's grant and stops its context while preserving the bot and other user" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    transport = RequestAuthorizerSupport::Transport.new
    user = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
    bot = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:bot))
    other = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:user, "U_INSTALLER"))
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock)

    service.apply(delivery).applied?.should be_true
    service.apply(delivery).already_absent?.should be_true
    store.mutation_count.should eq(1)
    expect_raises(Slack::Auth::ContractError) { user.dispatch("POST", "auth.test") }.code.conflict?.should be_true
    bot.dispatch("POST", "auth.test")
    other.dispatch("POST", "auth.test")
    transport.requests.map(&.headers["Authorization"]).should eq(["Bearer bot-token", "Bearer installer-token"])
  end

  it "matches bot user IDs exactly and never treats a user ID in the bot list as a user grant" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    wrong_bot = CredentialLifecycleSpec.body("bot_revoked").gsub("U_BOT", "U_ACTOR")
    service.process(CredentialLifecycleSpec.request(wrong_bot, clock.now), key).already_absent?.should be_true
    store.mutation_count.should eq(0)
    service.apply(CredentialLifecycleSpec.prepare(service, clock, "bot_revoked")).applied?.should be_true
    record = store.fetch(key).should_not(be_nil)
    record.bot.should be_nil
    record.users.keys.sort!.should eq(["U_ACTOR", "U_INSTALLER"])
  end

  it "deletes all installation data for the exact owner and blocks a previous context" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    record = RequestAuthorizerSupport.seed(store, key)
    store.store(key, Slack::Auth::InstallationPatch.new(webhook: Slack::Auth::IncomingWebhook.new(
      Slack::Auth::Secret.new("https://synthetic.example/hook"), "C1")), record.version)
    other = RequestAuthorizerSupport.workspace_key("T_OTHER")
    RequestAuthorizerSupport.seed(store, other)
    transport = RequestAuthorizerSupport::Transport.new
    context = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:bot))
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = service.prepare(CredentialLifecycleSpec.request(CredentialLifecycleSpec.body("app_uninstalled"), clock.now))
    service.apply(delivery).applied?.should be_true
    tombstone = store.fetch(key).should_not(be_nil)
    tombstone.deleted?.should be_true
    tombstone.bot.should be_nil
    tombstone.users.should be_empty
    tombstone.webhook.should be_nil
    store.fetch(other).should_not(be_nil).deleted?.should be_false
    expect_raises(Slack::Auth::ContractError) { context.dispatch("POST", "auth.test") }
    transport.requests.should be_empty
  end

  it "handles duplicates and both uninstall/revocation orders using original preparations" do
    {false, true}.each do |uninstall_first|
      clock = RequestAuthorizerSupport::Clock.new
      store = CredentialLifecycleSupport::Store.new(clock)
      key = RequestAuthorizerSupport.workspace_key
      RequestAuthorizerSupport.seed(store, key)
      service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
      uninstall = CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")
      revoke = CredentialLifecycleSpec.prepare(service, clock)
      first, second = uninstall_first ? {uninstall, revoke} : {revoke, uninstall}
      service.apply(first).applied?.should be_true
      service.apply(second)
      service.apply(first).already_absent?.should be_true
      service.apply(second).already_absent?.should be_true
      store.fetch(key).should_not(be_nil).deleted?.should be_true
    end
  end

  it "prepares and processes missing and expired credentials without acquisition" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    store.acquire_failure = Slack::Auth::ErrorCode::MissingGrant
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    service.apply(CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")).already_absent?.should be_true
    store.store(key, Slack::Auth::InstallationPatch.new(bot: RequestAuthorizerSupport.grant("U_BOT", "expired", clock.now)), nil)
    service.apply(CredentialLifecycleSpec.prepare(service, clock, "bot_revoked")).applied?.should be_true
    service.apply(CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")).applied?.should be_true
    store.acquire_count.should eq(0)
    store.dispatch_count.should eq(0)
  end

  it "preserves a reinstall and new grants when an old prepared delivery is replayed" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    transport = RequestAuthorizerSupport::Transport.new
    context = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:bot))
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    uninstall = CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")
    revoke = CredentialLifecycleSpec.prepare(service, clock)
    service.apply(uninstall)
    tombstone = store.fetch(key).should_not(be_nil)
    absent = CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")
    reinstalled = store.store(key, Slack::Auth::InstallationPatch.new(
      bot: RequestAuthorizerSupport.grant("U_BOT", "new-bot"),
      users: {"U_ACTOR" => RequestAuthorizerSupport.grant("U_ACTOR", "new-user")}), tombstone.version)
    {uninstall, revoke, absent}.each { |delivery| service.apply(delivery).superseded?.should be_true }
    store.fetch(key).should_not(be_nil).version.should eq(reinstalled.version)
    expect_raises(Slack::Auth::ContractError) { context.dispatch("POST", "auth.test") }.code.conflict?.should be_true
    transport.requests.should be_empty
  end

  it "does not apply a missing-installation preparation to a later first installation" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")
    record = RequestAuthorizerSupport.seed(store, key)
    service.apply(delivery).superseded?.should be_true
    store.fetch(key).should_not(be_nil).version.should eq(record.version)
  end

  it "rejects same-generation replacement targets but permits unrelated grant changes" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    initial = RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    user = CredentialLifecycleSpec.prepare(service, clock)
    bot = CredentialLifecycleSpec.prepare(service, clock, "bot_revoked")
    updated = store.store(key, Slack::Auth::InstallationPatch.new(users: {
      "U_ACTOR" => RequestAuthorizerSupport.grant("U_ACTOR", "new-user"),
    }), initial.version)
    expect_raises(Slack::Auth::ContractError) { service.apply(user) }.code.conflict?.should be_true
    store.fetch(key).should_not(be_nil).version.should eq(updated.version)
    service.apply(bot).applied?.should be_true
    store.fetch(key).should_not(be_nil).users["U_ACTOR"].grant.access_token.value.should eq("new-user")
  end

  it "retries a competing unrelated CAS write without recapturing the target grant" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    initial = RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock)
    store.before_mutation = -> {
      store.store(key, Slack::Auth::InstallationPatch.new(bot: RequestAuthorizerSupport.grant("U_BOT", "changed")), initial.version)
      nil
    }
    service.apply(delivery).applied?.should be_true
    store.mutation_count.should eq(2)
    store.fetch(key).should_not(be_nil).bot.should_not(be_nil).grant.access_token.value.should eq("changed")
  end

  it "never crosses a delete/reinstall between its read and mutation" do
    {"app_uninstalled", "tokens_revoked"}.each do |name|
      clock = RequestAuthorizerSupport::Clock.new
      store = CredentialLifecycleSupport::Store.new(clock)
      key = RequestAuthorizerSupport.workspace_key
      initial = RequestAuthorizerSupport.seed(store, key)
      service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
      delivery = CredentialLifecycleSpec.prepare(service, clock, name)
      store.before_mutation = -> {
        tombstone = store.delete(key, initial.version)
        store.store(key, Slack::Auth::InstallationPatch.new(bot: RequestAuthorizerSupport.grant("U_BOT", "new-install")), tombstone.version)
        nil
      }
      service.apply(delivery).superseded?.should be_true
      store.fetch(key).should_not(be_nil).bot.should_not(be_nil).grant.access_token.value.should eq("new-install")
    end
  end

  it "bounds conflicts and propagates persistence failures" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    record = RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock)
    store.mutation_failure = Slack::Auth::ErrorCode::Conflict
    expect_raises(Slack::Auth::ContractError) { service.apply(delivery) }.code.conflict?.should be_true
    store.mutation_count.should eq(3)
    store.mutation_failure = Slack::Auth::ErrorCode::PersistenceFailure
    expect_raises(Slack::Auth::ContractError) { service.apply(delivery) }.code.persistence_failure?.should be_true
    store.mutation_count.should eq(4)
    store.fetch(key).should_not(be_nil).version.should eq(record.version)
  end

  it "fences dispatched refresh leases after targeted revocation and uninstall" do
    {"bot_revoked", "tokens_revoked", "app_uninstalled"}.each do |name|
      clock = RequestAuthorizerSupport::Clock.new
      store = CredentialLifecycleSupport::Store.new(clock)
      key = RequestAuthorizerSupport.workspace_key
      store.store(key, Slack::Auth::InstallationPatch.new(bot: CredentialLifecycleSpec.refreshable("U_BOT"),
        users: {"U_ACTOR" => CredentialLifecycleSpec.refreshable("U_ACTOR")}), nil)
      grant_key = name == "tokens_revoked" ? Slack::Auth::GrantKey.new(:user, "U_ACTOR") : Slack::Auth::GrantKey.new(:bot)
      subject = name == "tokens_revoked" ? "U_ACTOR" : "U_BOT"
      query = Slack::Auth::InstallationQuery.new(key, grant_key)
      reference = store.acquire(query)
      lease = store.claim_refresh(reference, 1.minute)
      store.mark_refresh_dispatched(lease)
      service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
      delivery = CredentialLifecycleSpec.prepare(service, clock, name)
      service.apply(delivery).applied?.should be_true
      expect_raises(Slack::Auth::ContractError) { store.complete_refresh(lease, CredentialLifecycleSpec.refreshable(subject, "late")) }
      expect_raises(Slack::Auth::ContractError) { store.credential_for_dispatch(reference) }
      store.fetch(key).should_not(be_nil).grant(grant_key).should be_nil
      store.acquire_count.should eq(1)
    end
  end

  it "allows uninstall after refresh completion in the prepared generation" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    store.store(key, Slack::Auth::InstallationPatch.new(bot: CredentialLifecycleSpec.refreshable("U_BOT")), nil)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    lease = store.claim_refresh(store.acquire(query), 1.minute)
    store.mark_refresh_dispatched(lease)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    uninstall = CredentialLifecycleSpec.prepare(service, clock, "app_uninstalled")
    revoked = CredentialLifecycleSpec.prepare(service, clock, "bot_revoked")
    store.complete_refresh(lease, CredentialLifecycleSpec.refreshable("U_BOT", "rotated"))
    expect_raises(Slack::Auth::ContractError) { service.apply(revoked) }.code.conflict?.should be_true
    service.apply(uninstall).applied?.should be_true
    store.fetch(key).should_not(be_nil).deleted?.should be_true
  end

  it "rejects forged, unsigned, and stale requests before any store access" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    body = CredentialLifecycleSpec.body("app_uninstalled")
    forged = CredentialLifecycleSpec.request(body, clock.now)
    forged.headers["X-Slack-Signature"] = "v0=#{"0" * 64}"
    expect_raises(Slack::Errors::SignatureMismatch) { service.prepare(forged) }
    expect_raises(Slack::Errors::InvalidWebhookRequest) { service.prepare(HTTP::Request.new("POST", "/events", body: body)) }
    expect_raises(Slack::Errors::ReplayAttack) do
      service.prepare(CredentialLifecycleSpec.request(body, clock.now - 6.minutes))
    end
    store.fetch_count.should eq(0)
    store.acquire_count.should eq(0)
    store.mutation_count.should eq(0)
  end

  it "rejects invalid payloads and ambiguous ownership before accessing the store" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    body = CredentialLifecycleSpec.body("app_uninstalled")
    payloads = ["{}", body.gsub("A1", "A_OTHER"), body.gsub("event_callback", "url_verification"), body.sub("T1", "T_OTHER"),
                body.gsub("app_uninstalled", "unknown_event"),
                CredentialLifecycleSpec.body.gsub("U_ACTOR", ""),
                CredentialLifecycleSpec.body.gsub(%("U_ACTOR"), "7")]
    payloads.each do |payload|
      expect_raises(Slack::Auth::RequestAuthorizationError) do
        service.prepare(CredentialLifecycleSpec.request(payload, clock.now))
      end
    end
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      service.prepare(CredentialLifecycleSpec.request(CredentialLifecycleSpec.body, clock.now))
    end.reason.should eq(:missing_owner)
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      service.prepare(CredentialLifecycleSpec.request(CredentialLifecycleSpec.body, clock.now), RequestAuthorizerSupport.workspace_key("OTHER"))
    end.reason.should eq(:owner_not_authorized)
    store.fetch_count.should eq(0)
    store.mutation_count.should eq(0)
  end

  it "binds preparation to the store instance and app before applying cleanup" do
    clock = RequestAuthorizerSupport::Clock.new
    first = CredentialLifecycleSupport::Store.new(clock)
    second = CredentialLifecycleSupport::Store.new(clock)
    {first, second}.each { |store| RequestAuthorizerSupport.seed(store, RequestAuthorizerSupport.workspace_key) }
    service = Slack::Auth::CredentialLifecycle.new("A1", first, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock)
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      Slack::Auth::CredentialLifecycle.new("A1", second).apply(delivery)
    end.reason.should eq(:store_mismatch)
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      Slack::Auth::CredentialLifecycle.new("OTHER", first).apply(delivery)
    end.reason.should eq(:app_mismatch)
    second.fetch_count.should eq(0)
    second.mutation_count.should eq(0)
    delivery.targets.clear
    service.apply(delivery).applied?.should be_true
  end

  it "requires one authorized exact tenant and does not confuse an organization with its workspace" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    workspace = RequestAuthorizerSupport.workspace_key("T1", "E_ORG")
    organization = RequestAuthorizerSupport.org_key
    {workspace, organization}.each { |key| RequestAuthorizerSupport.seed(store, key) }
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    payload = JSON.parse(CredentialLifecycleSpec.body("app_uninstalled"))
    payload.as_h["authorizations"] = JSON.parse(<<-JSON)
      [
        {"team_id":"T1","enterprise_id":"E_ORG","user_id":"U_BOT","is_bot":true,"is_enterprise_install":false},
        {"team_id":null,"enterprise_id":"E_ORG","user_id":"U_BOT","is_bot":true,"is_enterprise_install":true}
      ]
      JSON
    body = payload.to_json
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      service.prepare(CredentialLifecycleSpec.request(body, clock.now))
    end.reason.should eq(:ambiguous_owner)
    expect_raises(Slack::Auth::RequestAuthorizationError) do
      service.prepare(CredentialLifecycleSpec.request(body, clock.now), RequestAuthorizerSupport.workspace_key)
    end.reason.should eq(:owner_not_authorized)
    store.fetch_count.should eq(0)
    service.process(CredentialLifecycleSpec.request(body, clock.now), organization).applied?.should be_true
    store.fetch(workspace).should_not(be_nil).deleted?.should be_false
    store.fetch(organization).should_not(be_nil).deleted?.should be_true
  end

  it "keeps absent targets absent from the prepared selection even if granted before apply" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    initial = RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    body = CredentialLifecycleSpec.body.gsub("U_ACTOR", "U_NEW")
    delivery = service.prepare(CredentialLifecycleSpec.request(body, clock.now), key)
    updated = store.store(key, Slack::Auth::InstallationPatch.new(users: {
      "U_NEW" => RequestAuthorizerSupport.grant("U_NEW", "new-user"),
    }), initial.version)
    service.apply(delivery).already_absent?.should be_true
    store.fetch(key).should_not(be_nil).version.should eq(updated.version)
  end

  it "reports its successful removal when a competing cleanup removes the remaining target before a CAS retry" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    body = CredentialLifecycleSpec.body.gsub(%("U_ACTOR"), %("U_ACTOR", "U_INSTALLER"))
    delivery = service.prepare(CredentialLifecycleSpec.request(body, clock.now), key)
    store.before_mutation = -> {
      store.before_mutation = -> {
        current = store.fetch(key).should_not(be_nil)
        current.users.keys.should eq(["U_INSTALLER"])
        store.invalidate(key, Slack::Auth::GrantKey.new(:user, "U_INSTALLER"), current.version)
        nil
      }
      nil
    }

    service.apply(delivery).applied?.should be_true
    record = store.fetch(key).should_not(be_nil)
    record.users.should be_empty
    record.bot.should_not be_nil
    service.apply(delivery).already_absent?.should be_true
  end

  it "resumes partial multi-user cleanup using the original revisions after a storage failure" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    body = CredentialLifecycleSpec.body.gsub(%("U_ACTOR"), %("U_ACTOR", "U_INSTALLER", "U_ACTOR"))
    delivery = service.prepare(CredentialLifecycleSpec.request(body, clock.now), key)
    store.before_mutation = -> {
      store.before_mutation = -> { store.mutation_failure = Slack::Auth::ErrorCode::PersistenceFailure; nil }
      nil
    }
    expect_raises(Slack::Auth::ContractError) { service.apply(delivery) }.code.persistence_failure?.should be_true
    store.fetch(key).should_not(be_nil).users.keys.should eq(["U_INSTALLER"])
    store.mutation_failure = nil
    service.apply(delivery).applied?.should be_true
    record = store.fetch(key).should_not(be_nil)
    record.users.should be_empty
    record.bot.should_not be_nil
    service.apply(delivery).already_absent?.should be_true
  end

  it "cleans quarantined credentials and permits applying verified work after the HTTP time window" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    store.store(key, Slack::Auth::InstallationPatch.new(bot: CredentialLifecycleSpec.refreshable("U_BOT")), nil)
    query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
    lease = store.claim_refresh(store.acquire(query), 1.minute)
    store.mark_refresh_dispatched(lease)
    store.fail_refresh(lease, Slack::Auth::RefreshFailure::UnknownRemoteOutcome)
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    delivery = CredentialLifecycleSpec.prepare(service, clock, "bot_revoked")
    clock.now += 1.hour
    store.acquire_failure = Slack::Auth::ErrorCode::UnknownRemoteOutcome
    service.apply(delivery).applied?.should be_true
    store.acquire_count.should eq(1)
    store.refresh_status(query).should be_nil
  end

  it "blocks a waiting context when revocation completes before its dispatch barrier" do
    clock = RequestAuthorizerSupport::Clock.new
    store = CredentialLifecycleSupport::Store.new(clock)
    key = RequestAuthorizerSupport.workspace_key
    RequestAuthorizerSupport.seed(store, key)
    transport = RequestAuthorizerSupport::Transport.new
    context = CredentialLifecycleSpec.context(store, transport, Slack::Auth::GrantKey.new(:user, "U_ACTOR"))
    service = Slack::Auth::CredentialLifecycle.new("A1", store, -> { clock.now })
    start = Channel(Bool).new(1)
    result = Channel(Slack::Auth::ErrorCode?).new(1)
    # This fiber waits until cleanup commits. The parent joins it before closing channels.
    spawn do
      if start.receive?
        begin
          context.dispatch("POST", "auth.test")
          result.send(nil)
        rescue error : Slack::Auth::ContractError
          result.send(error.code)
        end
      end
    end
    begin
      service.apply(CredentialLifecycleSpec.prepare(service, clock))
      start.send(true)
      select
      when code = result.receive
        code.should eq(Slack::Auth::ErrorCode::Conflict)
      when timeout(5.seconds)
        fail "context dispatch timed out"
      end
      transport.requests.should be_empty
    ensure
      start.close
      result.close
    end
  end
end
