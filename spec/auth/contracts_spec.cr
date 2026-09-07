require "../spec_helper"
require "../support/auth/protocol_store"

private def present(value)
  value || raise "Expected a contract value"
end

private def secret(value = "synthetic-token")
  Slack::Auth::Secret.new(value)
end

private def grant(id = "B1", value = "synthetic-token")
  Slack::Auth::Grant.new(id, secret(value), ["chat:write"], refresh_token: secret("synthetic-refresh"))
end

private def key(team = "T1")
  Slack::Auth::InstallationKey.new("A1", :workspace, team_id: team)
end

private def query(team = "T1", user : String? = nil)
  Slack::Auth::InstallationQuery.new(key(team), Slack::Auth::GrantKey.new(user ? Slack::Auth::TokenKind::User : Slack::Auth::TokenKind::Bot, user),
    actor_user_id: "external-actor", visible_team_id: "external-team")
end

private def protocol
  clock = AuthSupport::FakeClock.new
  store = AuthSupport::ProtocolStore.new(clock)
  store.store(key, Slack::Auth::InstallationPatch.new(bot: grant), nil)
  {store, clock}
end

private def error(code : Slack::Auth::ErrorCode, &)
  failure = expect_raises(Slack::Auth::ContractError) { yield }
  failure.code.should eq(code)
end

describe "authentication contracts" do
  it "supports the shared clock and rejects ambiguous installation/token keys" do
    Slack::Auth::SystemClock.new.now.location.should eq(Time::Location::UTC)
    error(:invalid_identity) { Slack::Auth::InstallationKey.new("A", :workspace) }
    error(:invalid_identity) { Slack::Auth::InstallationKey.new("A", :organization, "E", "T") }
    Slack::Auth::InstallationKey.new("A", :organization, "E").team_id.should be_nil
    error(:invalid_identity) { Slack::Auth::GrantKey.new(:user) }
    error(:invalid_identity) { Slack::Auth::GrantKey.new(:bot, "U") }
  end

  it "requires a nonce only for future OIDC attempts" do
    clock = AuthSupport::FakeClock.new
    error(:invalid_configuration) do
      Slack::Auth::AuthorizationAttempt.new(secret, secret, :oidc, clock.now, "https://example.test/callback")
    end
    attempt = Slack::Auth::AuthorizationAttempt.new(secret, secret, :oidc, clock.now,
      "https://example.test/callback", secret("nonce"))
    present(attempt.nonce).value.should eq("nonce")
  end

  it "consumes state atomically with session, purpose, expiry and independent tabs" do
    clock = AuthSupport::FakeClock.new
    store = AuthSupport::StateStore.new(clock)
    ["tab1", "tab2"].each do |state|
      store.issue(Slack::Auth::AuthorizationAttempt.new(secret(state), secret("session"), :installation,
        clock.now + 1.minute, "https://example.test/callback"))
    end
    error(:invalid_state) { store.consume(secret("tab1"), secret("other"), :installation) }
    error(:invalid_state) { store.consume(secret("tab1"), secret("session"), :oidc) }
    results = Channel(Bool).new
    2.times do
      spawn do
        store.consume(secret("tab1"), secret("session"), :installation)
        results.send(true)
      rescue Slack::Auth::ContractError
        results.send(false)
      end
    end
    [results.receive, results.receive].count(true).should eq(1)
    store.consume(secret("tab2"), secret("session"), :installation).state.value.should eq("tab2")
    store.issue(Slack::Auth::AuthorizationAttempt.new(secret("expired"), secret("session"), :installation,
      clock.now, "https://example.test/callback"))
    error(:invalid_state) { store.consume(secret("expired"), secret("session"), :installation) }
  end

  it "rejects state collisions without overwriting the original attempt" do
    clock = AuthSupport::FakeClock.new
    store = AuthSupport::StateStore.new(clock)
    attempt = Slack::Auth::AuthorizationAttempt.new(secret, secret("session"), :installation,
      clock.now + 1.minute, "https://example.test/callback")
    store.issue(attempt)
    error(:conflict) { store.issue(attempt) }
    store.consume(secret, secret("session"), :installation).should eq(attempt)
  end

  it "preserves separate users and tenants and uses explicit ownership" do
    store, _ = protocol
    record = present(store.fetch(key))
    patch = Slack::Auth::InstallationPatch.new(users: {"U1" => grant("U1"), "U2" => grant("U2")})
    record = store.store(key, patch, record.version)
    store.store(key("T2"), Slack::Auth::InstallationPatch.new(bot: grant("B2", "tenant-two")), nil)
    record = store.store(key, Slack::Auth::InstallationPatch.new(users: {"U1" => grant("U1", "updated")}), record.version)
    record.users.keys.sort!.should eq(["U1", "U2"])
    store.credential_for_dispatch(store.acquire(query("T1", "U1"))).value.should eq("updated")
    store.credential_for_dispatch(store.acquire(query("T2"))).value.should eq("tenant-two")
    error(:missing_installation) { store.acquire(query("missing")) }
    error(:missing_grant) { store.acquire(query("T2", "U1")) }
    error(:conflict) { store.store(key, patch, nil) }
    record.users.clear
    record.users.size.should eq(2)
  end

  it "reclaims only expired pre-dispatch ownership and fences the old holder" do
    store, clock = protocol
    reference = store.acquire(query)
    first = store.claim_refresh(reference, 1.minute)
    error(:refresh_busy) { store.claim_refresh(reference, 1.minute) }
    clock.now += 1.minute
    second = store.claim_refresh(reference, 1.minute)
    second.fence.should be > first.fence
    error(:conflict) { store.mark_refresh_dispatched(first) }
    store.release_refresh(second)
    store.refresh_status(query).should be_nil
  end

  it "quarantines a crashed dispatched refresh without a blind retry" do
    store, clock = protocol
    reference = store.acquire(query)
    lease = store.claim_refresh(reference, 1.minute)
    store.mark_refresh_dispatched(lease)
    error(:refresh_busy) { store.credential_for_dispatch(reference) }
    clock.now += 1.minute
    error(:unknown_remote_outcome) { store.claim_refresh(reference, 1.minute) }
    error(:unknown_remote_outcome) { store.credential_for_dispatch(reference) }
    error(:conflict) { store.complete_refresh(lease, grant("B1", "late")) }
    error(:conflict) { store.release_refresh(lease) }
  end

  it "persists successful rotation and rejects the old credential reference" do
    store, _ = protocol
    reference = store.acquire(query)
    lease = store.claim_refresh(reference, 1.minute)
    error(:conflict) { store.complete_refresh(lease, grant) }
    store.mark_refresh_dispatched(lease)
    record = store.complete_refresh(lease, grant("B1", "rotated"))
    present(record.bot).grant.access_token.value.should eq("rotated")
    error(:conflict) { store.credential_for_dispatch(reference) }
    store.credential_for_dispatch(store.acquire(query)).value.should eq("rotated")
    error(:conflict) { store.complete_refresh(lease, grant) }
  end

  it "separates rejected refresh from unknown remote outcome" do
    [Slack::Auth::RefreshFailure::Rejected, Slack::Auth::RefreshFailure::UnknownRemoteOutcome].each do |failure|
      store, _ = protocol
      reference = store.acquire(query)
      lease = store.claim_refresh(reference, 1.minute)
      store.mark_refresh_dispatched(lease)
      store.fail_refresh(lease, failure)
      if failure.rejected?
        error(:missing_grant) { store.acquire(query) }
      else
        error(:unknown_remote_outcome) { store.claim_refresh(reference, 1.minute) }
      end
    end
  end

  it "cannot resurrect revoked credentials or cross reinstall generations" do
    store, _ = protocol
    reference = store.acquire(query)
    lease = store.claim_refresh(reference, 1.minute)
    store.mark_refresh_dispatched(lease)
    record = store.invalidate(key, query.grant, present(store.fetch(key)).version)
    error(:conflict) { store.complete_refresh(lease, grant) }
    error(:conflict) { store.credential_for_dispatch(reference) }
    tombstone = store.delete(key, record.version)
    tombstone.deleted?.should be_true
    replacement = store.store(key, Slack::Auth::InstallationPatch.new(bot: grant), tombstone.version)
    replacement.version.generation.should be > reference.generation
    error(:conflict) { store.complete_refresh(lease, grant) }
    error(:conflict) { store.delete(key, record.version) }
    store.credential_for_dispatch(store.acquire(query)).value.should eq("synthetic-token")
  end

  it "allows independent grants to refresh and rejects tokens at expiry" do
    store, clock = protocol
    store.store(key, Slack::Auth::InstallationPatch.new(users: {"U1" => grant("U1")}), present(store.fetch(key)).version)
    bot = store.claim_refresh(store.acquire(query), 1.minute)
    user = store.claim_refresh(store.acquire(query("T1", "U1")), 1.minute)
    store.mark_refresh_dispatched(bot)
    store.mark_refresh_dispatched(user)
    store.complete_refresh(bot, grant)
    store.complete_refresh(user, Slack::Auth::Grant.new("U1", secret, [] of String, expires_at: clock.now))
    error(:reauthorization_required) { store.credential_for_dispatch(store.acquire(query("T1", "U1"))) }
  end

  it "supports observable offline transport and redacts sensitive diagnostics" do
    transport = AuthSupport::RecordingTransport.new
    response = Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, "canary-response")
    transport.enqueue(response)
    request = Slack::Auth::TransportRequest.new("POST", URI.parse("https://example.test/token?code=canary"),
      HTTP::Headers{"Authorization" => "canary-header"}, "canary-body")
    transport.execute(request).should eq(response)
    transport.requests.first.body.should eq("canary-body")
    error(:transport_failure) { transport.execute(request) }
    [request.inspect, request.to_s, response.inspect, response.to_s, grant("B1", "canary").inspect,
     Slack::Auth::ContractError.new(:invalid_response, 429, 1.second).inspect].each do |diagnostic|
      diagnostic.should_not contain("canary")
    end
    Slack::Auth::APIConfiguration.new(URI.parse("https://example.test/api/")).base_uri.host.should eq("example.test")
    Slack::Auth::OAuthConfiguration.new(URI.parse("https://example.test/authorize"), URI.parse("https://example.test/token"),
      "A1", secret, URI.parse("https://example.test/callback")).client_id.should eq("A1")
    Slack::Auth::OIDCConfiguration.new(URI.parse("https://example.test/discovery"), "issuer", "A1").issuer.should eq("issuer")
    Slack::Auth::TransportOptions.new.read_timeout.should eq(30.seconds)
  end
end
