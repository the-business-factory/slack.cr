require "../spec_helper"
require "../support/rotation/helpers"

describe Slack::Auth::RotationService do
  clock = StorageSupport::Clock.new
  store = Slack::Auth::MemoryInstallationStore.new(clock)
  transport = RotationSupport::Transport.new
  service = RotationSupport.service(store, transport, clock)

  before_each do
    clock = StorageSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    transport = RotationSupport::Transport.new
    service = RotationSupport.service(store, transport, clock)
    RotationSupport.seed(store, clock.now)
  end

  it "preserves fresh credentials without HTTP and rotates at the exact margin" do
    original = store.acquire(RotationSupport.query)
    clock.now -= 1.nanosecond
    service.rotate(RotationSupport.query).should eq(original)
    transport.requests.should be_empty
    clock.now += 1.nanosecond
    current = service.rotate(RotationSupport.query)
    current.grant_revision.should be > original.grant_revision
    store.credential_for_dispatch(current).value.should eq("synthetic-next-bot")
    transport.requests.size.should eq(1)
    service.rotate(RotationSupport.query).should eq(current)
    transport.requests.size.should eq(1)
  end

  it "supports a zero margin at exact expiry and rejects unbounded policies" do
    policy = Slack::Auth::RotationPolicy.new(refresh_margin: Time::Span.zero)
    service = Slack::Auth::RotationService.new(store,
      Slack::Auth::RefreshClient.new(RotationSupport.configuration, transport), clock: clock, policy: policy)
    clock.now += 5.minutes - 1.nanosecond
    service.rotate(RotationSupport.query)
    transport.requests.should be_empty
    clock.now += 1.nanosecond
    service.rotate(RotationSupport.query)
    transport.requests.size.should eq(1)
    [-1.second, 1.hour + 1.second].each do |margin|
      expect_raises(Slack::Auth::ContractError) { Slack::Auth::RotationPolicy.new(refresh_margin: margin) }
    end
    [Time::Span.zero, 10.minutes + 1.second].each do |duration|
      expect_raises(Slack::Auth::ContractError) { Slack::Auth::RotationPolicy.new(lease_duration: duration) }
    end
  end

  it "preserves long-lived grants and fails closed for an expiring grant without refresh credentials" do
    record = store.fetch(RotationSupport.query.owner).should_not(be_nil)
    store.store(record.key, Slack::Auth::InstallationPatch.new(bot: RotationSupport.grant("B1", refresh: nil)), record.version)
    service.rotate(RotationSupport.query)
    transport.requests.should be_empty
    record = store.fetch(record.key).should_not(be_nil)
    store.store(record.key, Slack::Auth::InstallationPatch.new(bot: RotationSupport.grant("B1", clock.now, nil)), record.version)
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
    transport.requests.should be_empty
  end

  it "rotates bot and each user independently and preserves unrelated updates during HTTP" do
    bot = store.acquire(RotationSupport.query)
    user2 = store.acquire(RotationSupport.query("U2"))
    transport.response = RotationSupport.response("user")
    transport.before_response = -> {
      record = store.fetch(RotationSupport.query.owner).should_not(be_nil)
      store.store(record.key, Slack::Auth::InstallationPatch.new(bot: RotationSupport.grant("B1", clock.now + 2.hours)), record.version)
      nil
    }
    user = service.rotate(RotationSupport.query("U1"))
    store.credential_for_dispatch(user).value.should eq("synthetic-next-user")
    store.credential_for_dispatch(user2).value.should eq("synthetic-old-U2")
    expect_raises(Slack::Auth::ContractError) { store.credential_for_dispatch(bot) }
    transport.before_response = nil
    service.rotate(RotationSupport.query)
    transport.requests.size.should eq(1)
    stored = store.fetch(RotationSupport.query.owner).should_not(be_nil)
    stored.users["U1"].grant.expires_at.should eq(clock.now + 1800.seconds)
    stored.users["U1"].grant.scopes.should eq(["search:read"])
  end

  it "uses exchange start time for expiry despite a slow response" do
    start = clock.now
    transport.before_response = -> { clock.now += 30.seconds; nil }
    service.rotate(RotationSupport.query)
    store.fetch(RotationSupport.query.owner).should_not(be_nil).bot.should_not(be_nil).grant.expires_at.should eq(start + 3600.seconds)
  end

  it "uses the replacement refresh token in the next rotation cycle" do
    service.rotate(RotationSupport.query)
    clock.now += 55.minutes
    response = RotationSupport.response
    transport.response = Slack::Auth::TransportResponse.new(response.status, response.headers,
      response.body.gsub("synthetic-next", "synthetic-third"))
    reference = service.rotate(RotationSupport.query)
    transport.requests.map { |request| URI::Params.parse(request.body.should_not(be_nil))["refresh_token"] }
      .should eq(["synthetic-refresh", "synthetic-next-refresh"])
    store.credential_for_dispatch(reference).value.should eq("synthetic-third-bot")
  end

  it "allows only one effective refresh while a fiber owns the exchange" do
    started = Channel(Nil).new(1)
    finish = Channel(Nil).new(1)
    result = Channel(Slack::Auth::CredentialReference | Exception).new(1)
    transport.before_response = -> {
      started.send(nil)
      select
      when finish.receive
      when timeout(5.seconds)
        raise "refresh test barrier timed out"
      end
      nil
    }
    # The test joins its sole worker before closing channels; no fiber outlives it.
    spawn do
      result.send(service.rotate(RotationSupport.query))
    rescue error
      result.send(error)
    end
    begin
      select
      when started.receive
      when timeout(5.seconds)
        fail "refresh did not start"
      end
      contender = RotationSupport.service(store, transport, clock)
      expect_raises(Slack::Auth::ContractError) { contender.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::RefreshBusy)
    ensure
      finish.send(nil)
      select
      when value = result.receive
        value.should be_a(Slack::Auth::CredentialReference)
      when timeout(5.seconds)
        fail "refresh did not complete"
      end
      started.close
      finish.close
      result.close
    end
    transport.requests.size.should eq(1)
  end

  {"invalid_refresh_token", "invalid_grant", "token_revoked"}.each do |remote|
    it "removes only the selected grant after #{remote}" do
      transport.response = Slack::Auth::TransportResponse.new(200, HTTP::Headers.new, %({"ok":false,"error":"#{remote}"}))
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
      store.fetch(RotationSupport.query.owner).should_not(be_nil).bot.should be_nil
      store.credential_for_dispatch(store.acquire(RotationSupport.query("U1"))).value.should eq("synthetic-old-U1")
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }
      transport.requests.size.should eq(1)
    end
  end

  {Slack::Auth::ErrorCode::TransportFailure, Slack::Auth::ErrorCode::UnknownRemoteOutcome}.each do |code|
    it "quarantines #{code} without resending the refresh token" do
      transport.before_response = -> : Nil { raise Slack::Auth::ContractError.new(code) }
      original = store.acquire(RotationSupport.query)
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(code)
      store.refresh_status(RotationSupport.query).should_not(be_nil).phase.uncertain?.should be_true
      clock.now += 1.day
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
      expect_raises(Slack::Auth::ContractError) { store.credential_for_dispatch(original) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
      transport.requests.size.should eq(1)
    end
  end

  {"malformed", %({"ok":false,"error":"internal_error"}), %({"ok":false,"error":"ratelimited"})}.each do |body|
    it "quarantines an unusable response and keeps diagnostics safe" do
      transport.response = Slack::Auth::TransportResponse.new(503, HTTP::Headers{"Retry-After" => "3"}, body)
      error = expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }
      error.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
      error.retry_after.should eq(3.seconds)
      error.inspect.should_not contain(body)
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }
      transport.requests.size.should eq(1)
    end
  end

  it "quarantines a response for the wrong grant type" do
    transport.response = RotationSupport.response("user")
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    store.refresh_status(RotationSupport.query).should_not(be_nil).phase.uncertain?.should be_true
  end

  {429, 500}.each do |status|
    it "does not treat HTTP #{status} as proof of refresh-token rejection" do
      transport.response = Slack::Auth::TransportResponse.new(status, HTTP::Headers.new,
        %({"ok":false,"error":"invalid_refresh_token"}))
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
      store.fetch(RotationSupport.query.owner).should_not(be_nil).bot.should_not be_nil
      expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }
      transport.requests.size.should eq(1)
    end
  end

  it "rejects late completion at the lease deadline without another HTTP attempt" do
    transport.before_response = -> { clock.now += 2.minutes; nil }
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
    store.refresh_status(RotationSupport.query).should_not(be_nil).phase.uncertain?.should be_true
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }
    transport.requests.size.should eq(1)
  end

  it "cannot restore a grant replaced while refresh HTTP was in flight" do
    transport.before_response = -> {
      record = store.fetch(RotationSupport.query.owner).should_not(be_nil)
      store.store(record.key, Slack::Auth::InstallationPatch.new(bot: RotationSupport.grant("B1", clock.now + 2.hours, "new-authorization")), record.version)
      nil
    }
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
    store.fetch(RotationSupport.query.owner).should_not(be_nil).bot.should_not(be_nil).grant.refresh_token.should_not(be_nil).value.should eq("new-authorization")
  end
end
