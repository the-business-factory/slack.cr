require "../spec_helper"
require "../support/auth/oauth_state_fakes"

private def state_secret(value : String) : Slack::Auth::Secret
  Slack::Auth::Secret.new(value)
end

private def state_attempt(clock : Slack::Auth::Clock, state : String, session : String = "session",
                          purpose : Slack::Auth::AuthorizationPurpose = Slack::Auth::AuthorizationPurpose::Installation,
                          expires_at : Time = clock.now + 1.minute) : Slack::Auth::AuthorizationAttempt
  nonce = purpose.oidc? ? state_secret("nonce-#{state}") : nil
  Slack::Auth::AuthorizationAttempt.new(state_secret(state), state_secret(session), purpose,
    expires_at, "https://app.example.test/callback", nonce)
end

private def state_error(code : Slack::Auth::ErrorCode, &)
  error = expect_raises(Slack::Auth::ContractError) { yield }
  error.code.should eq(code)
end

private def bounded_receive(channel : Channel(Bool)) : Bool
  select
  when value = channel.receive
    value
  when timeout(1.second)
    raise "Timed out waiting for state consumer"
  end
end

describe Slack::Auth::MemoryStateStore do
  it "rejects unknown and replayed state" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    state_error(:invalid_state) { store.consume(state_secret("missing"), state_secret("session"), :installation) }
    store.issue(state_attempt(clock, "once"))
    store.consume(state_secret("once"), state_secret("session"), :installation).state.value.should eq("once")
    state_error(:invalid_state) { store.consume(state_secret("once"), state_secret("session"), :installation) }
  end

  it "accepts before expiry and rejects exact or later expiry" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "before", expires_at: clock.now + 1.nanosecond))
    store.consume(state_secret("before"), state_secret("session"), :installation).state.value.should eq("before")

    store.issue(state_attempt(clock, "exact", expires_at: clock.now))
    state_error(:invalid_state) { store.consume(state_secret("exact"), state_secret("session"), :installation) }
    store.issue(state_attempt(clock, "after", expires_at: clock.now - 1.nanosecond))
    state_error(:invalid_state) { store.consume(state_secret("after"), state_secret("session"), :installation) }
  end

  it "preserves attempts after wrong session or purpose" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "bound"))
    state_error(:invalid_state) { store.consume(state_secret("bound"), state_secret("other"), :installation) }
    state_error(:invalid_state) { store.consume(state_secret("bound"), state_secret("session"), :oidc) }
    store.consume(state_secret("bound"), state_secret("session"), :installation).state.value.should eq("bound")
  end

  it "keeps an expired colliding attempt instead of replacing it" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "collision", session: "original", expires_at: clock.now))
    state_error(:conflict) do
      store.issue(state_attempt(clock, "collision", session: "replacement", expires_at: clock.now + 1.minute))
    end
    state_error(:invalid_state) do
      store.consume(state_secret("collision"), state_secret("replacement"), :installation)
    end
    store.prune_expired.should eq(1)
  end

  it "supports independent tabs and OIDC purpose separation" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "tab-one"))
    store.issue(state_attempt(clock, "tab-two"))
    store.issue(state_attempt(clock, "oidc", purpose: Slack::Auth::AuthorizationPurpose::OIDC))
    store.consume(state_secret("tab-two"), state_secret("session"), :installation).state.value.should eq("tab-two")
    store.consume(state_secret("tab-one"), state_secret("session"), :installation).state.value.should eq("tab-one")
    state_error(:invalid_state) { store.consume(state_secret("oidc"), state_secret("session"), :installation) }
    store.consume(state_secret("oidc"), state_secret("session"), :oidc).nonce.try(&.value).should eq("nonce-oidc")
  end

  it "allows exactly one concurrent consumer without sleeps" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "race"))
    ready = Channel(Nil).new
    start = Channel(Nil).new
    results = Channel(Bool).new(2)
    2.times do
      spawn do
        ready.send(nil)
        start.receive
        store.consume(state_secret("race"), state_secret("session"), :installation)
        results.send(true)
      rescue Slack::Auth::ContractError
        results.send(false)
      end
    end
    2.times { ready.receive }
    2.times { start.send(nil) }
    [bounded_receive(results), bounded_receive(results)].count(true).should eq(1)
  end

  it "prunes expired entries during issue and on explicit cleanup" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryStateStore.new(clock)
    store.issue(state_attempt(clock, "old", expires_at: clock.now))
    store.issue(state_attempt(clock, "active"))
    store.prune_expired.should eq(0)
    clock.now += 1.minute
    store.prune_expired.should eq(1)
    state_error(:invalid_state) { store.consume(state_secret("active"), state_secret("session"), :installation) }
  end
end
