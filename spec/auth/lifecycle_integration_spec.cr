require "../spec_helper"
require "../support/auth/lifecycle_helpers"
require "../support/auth/lifecycle_transport"

describe "authentication lifecycle integration" do
  it "installs and rotates bot and user credentials independently before authorized API sends" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    installed = LifecycleSupport.install(store, oauth, clock)
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    bot = Slack::Auth::GrantKey.new(:bot)
    user = Slack::Auth::GrantKey.new(:user, "UUSER")

    original = authorizer.authorize_command(LifecycleSupport.command(clock), bot)
    LifecycleSupport.send(original, api)
    oauth.requests.size.should eq(1)
    api.requests.last.headers["Authorization"].should eq("Bearer synthetic-bot-access")

    clock.now += 55.minutes
    oauth.enqueue(LifecycleSupport.response("refresh_bot"))
    rotated = authorizer.authorize_command(LifecycleSupport.command(clock), bot)
    LifecycleSupport.send(rotated, api)
    api.requests.last.headers["Authorization"].should eq("Bearer synthetic-next-bot")
    store.fetch(installed.key).should_not(be_nil).users["UUSER"].grant.access_token.value.should eq("synthetic-user-access")

    expect_raises(Slack::Auth::ContractError) { original.dispatch("POST", "chat.postMessage") }
      .code.should eq(Slack::Auth::ErrorCode::Conflict)
    api.requests.size.should eq(2)

    oauth.enqueue(LifecycleSupport.response("refresh_user"))
    user_context = authorizer.authorize_command(LifecycleSupport.command(clock), user)
    LifecycleSupport.send(user_context, api)
    api.requests.last.headers["Authorization"].should eq("Bearer synthetic-next-user")
    LifecycleSupport.send(rotated, api)
    api.requests.last.headers["Authorization"].should eq("Bearer synthetic-next-bot")

    oauth.requests.map(&.uri.to_s).uniq!.should eq([LifecycleSupport::OAUTH_CONFIGURATION.token_uri.to_s])
    api.requests.map(&.uri.to_s).uniq!.should eq(["https://api.example.test/custom/api/chat.postMessage"])
    grants = oauth.requests.map { |request| URI::Params.parse(request.body || "") }
    grants[0]["code"].should eq("synthetic-code")
    grants[0]["redirect_uri"].should eq(LifecycleSupport::OAUTH_CONFIGURATION.redirect_uri.to_s)
    grants[1]["refresh_token"].should eq("synthetic-bot-refresh")
    grants[2]["refresh_token"].should eq("synthetic-user-refresh")
    grants[1]["grant_type"].should eq("refresh_token")
    grants[2]["grant_type"].should eq("refresh_token")
  end

  it "verifies signatures and exact ownership before a configured rotation service can send" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    LifecycleSupport.install(store, oauth, clock)
    clock.now += 1.hour
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    bot = Slack::Auth::GrantKey.new(:bot)
    forged = LifecycleSupport.command(clock)
    forged.headers["X-Slack-Signature"] = "v0=#{"0" * 64}"

    expect_raises(Slack::Errors::SignatureMismatch) { authorizer.authorize_command(forged, bot) }
    expect_raises(Slack::Auth::ContractError) do
      authorizer.authorize_command(LifecycleSupport.command(clock, "T_OTHER"), bot)
    end.code.should eq(Slack::Auth::ErrorCode::MissingInstallation)
    oauth.requests.size.should eq(1)
    api.requests.should be_empty
  end

  it "rejects rotation wired to a different installation store before remote work" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    other_store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    rotation = Slack::Auth::RotationService.new(other_store,
      Slack::Auth::RefreshClient.new(LifecycleSupport::OAUTH_CONFIGURATION, oauth), clock: clock)

    expect_raises(Slack::Auth::ContractError) do
      Slack::Auth::RequestAuthorizer.new("AAPP", store, api,
        LifecycleSupport::API_CONFIGURATION, rotation: rotation)
    end.code.should eq(Slack::Auth::ErrorCode::InvalidConfiguration)
    oauth.requests.should be_empty
    api.requests.should be_empty
  end

  it "keeps a waiting context fenced when its grant expires" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    LifecycleSupport.install(store, oauth, clock)
    context = LifecycleSupport.authorizer(store, oauth, api, clock)
      .authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))
    clock.now += 1.hour

    expect_raises(Slack::Auth::ContractError) { context.dispatch("POST", "chat.postMessage") }
      .code.should eq(Slack::Auth::ErrorCode::ReauthorizationRequired)
    oauth.requests.size.should eq(1)
    api.requests.should be_empty
  end

  it "revokes one user, uninstalls, and preserves a reinstall when prepared events are repeated" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    installed = LifecycleSupport.install(store, oauth, clock)
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    bot = authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))
    user = authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:user, "UUSER"))
    lifecycle = Slack::Auth::CredentialLifecycle.new("AAPP", store, -> { clock.now })
    revoke = lifecycle.prepare(LifecycleSupport.lifecycle_request(clock), installed.key)
    uninstall = lifecycle.prepare(LifecycleSupport.lifecycle_request(clock, uninstall: true), installed.key)

    lifecycle.apply(revoke).should eq(Slack::Auth::LifecycleOutcome::Applied)
    expect_raises(Slack::Auth::ContractError) { user.dispatch("POST", "chat.postMessage") }
    LifecycleSupport.send(bot, api)
    lifecycle.apply(uninstall).should eq(Slack::Auth::LifecycleOutcome::Applied)
    expect_raises(Slack::Auth::ContractError) { bot.dispatch("POST", "chat.postMessage") }
    api.requests.size.should eq(1)

    reinstalled = LifecycleSupport.install(store, oauth, clock)
    reinstalled.version.generation.should be > installed.version.generation
    lifecycle.apply(revoke).should eq(Slack::Auth::LifecycleOutcome::Superseded)
    lifecycle.apply(uninstall).should eq(Slack::Auth::LifecycleOutcome::Superseded)
    fresh = authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))
    LifecycleSupport.send(fresh, api)
    store.fetch(installed.key).should_not(be_nil).users.has_key?("UUSER").should be_true
  end

  it "cannot persist an in-flight refresh over uninstall and reinstall" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = LifecycleSupport::Transport.new
    api = OAuthStateSupport::RecordingTransport.new
    installed = LifecycleSupport.install(store, oauth, clock)
    lifecycle = Slack::Auth::CredentialLifecycle.new("AAPP", store, -> { clock.now })
    uninstall = lifecycle.prepare(LifecycleSupport.lifecycle_request(clock, uninstall: true), installed.key)
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    clock.now += 1.hour
    oauth.enqueue(LifecycleSupport.response("refresh_bot"))
    oauth.before_response = -> do
      lifecycle.apply(uninstall).should eq(Slack::Auth::LifecycleOutcome::Applied)
      oauth.before_response = nil
      LifecycleSupport.install(store, oauth, clock)
      nil
    end

    expect_raises(Slack::Auth::ContractError) do
      authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))
    end.code.should eq(Slack::Auth::ErrorCode::Conflict)
    record = store.fetch(installed.key).should_not be_nil
    record.version.generation.should be > installed.version.generation
    record.bot.should_not(be_nil).grant.access_token.value.should eq("synthetic-bot-access")
    oauth.requests.size.should eq(3)
    api.requests.should be_empty
    store.refresh_status(Slack::Auth::InstallationQuery.new(installed.key, Slack::Auth::GrantKey.new(:bot))).should be_nil
  end

  it "applies a prepared uninstall after rotation within the original installation generation" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    installed = LifecycleSupport.install(store, oauth, clock)
    lifecycle = Slack::Auth::CredentialLifecycle.new("AAPP", store, -> { clock.now })
    uninstall = lifecycle.prepare(LifecycleSupport.lifecycle_request(clock, uninstall: true), installed.key)
    clock.now += 1.hour
    oauth.enqueue(LifecycleSupport.response("refresh_bot"))
    context = LifecycleSupport.authorizer(store, oauth, api, clock)
      .authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))

    lifecycle.apply(uninstall).should eq(Slack::Auth::LifecycleOutcome::Applied)
    expect_raises(Slack::Auth::ContractError) { context.dispatch("POST", "chat.postMessage") }
      .code.should eq(Slack::Auth::ErrorCode::MissingInstallation)
    store.fetch(installed.key).should_not(be_nil).deleted?.should be_true
    api.requests.should be_empty
  end

  it "revokes an in-flight user refresh without invalidating the bot" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = LifecycleSupport::Transport.new
    api = OAuthStateSupport::RecordingTransport.new
    installed = LifecycleSupport.install(store, oauth, clock)
    lifecycle = Slack::Auth::CredentialLifecycle.new("AAPP", store, -> { clock.now })
    revoke = lifecycle.prepare(LifecycleSupport.lifecycle_request(clock), installed.key)
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    bot = authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:bot))
    clock.now += 30.minutes
    oauth.enqueue(LifecycleSupport.response("refresh_user"))
    oauth.before_response = -> do
      lifecycle.apply(revoke).should eq(Slack::Auth::LifecycleOutcome::Applied)
      nil
    end

    expect_raises(Slack::Auth::ContractError) do
      authorizer.authorize_command(LifecycleSupport.command(clock), Slack::Auth::GrantKey.new(:user, "UUSER"))
    end.code.should eq(Slack::Auth::ErrorCode::Conflict)
    store.fetch(installed.key).should_not(be_nil).users.should be_empty
    LifecycleSupport.send(bot, api)
    api.requests.last.headers["Authorization"].should eq("Bearer synthetic-bot-access")
    oauth.requests.size.should eq(2)
  end

  it "blocks both new authorization and existing dispatch after an uncertain refresh" do
    clock = OAuthStateSupport::Clock.new
    store = Slack::Auth::MemoryInstallationStore.new(clock)
    oauth = OAuthStateSupport::RecordingTransport.new
    api = OAuthStateSupport::RecordingTransport.new
    LifecycleSupport.install(store, oauth, clock)
    authorizer = LifecycleSupport.authorizer(store, oauth, api, clock)
    bot = Slack::Auth::GrantKey.new(:bot)
    context = authorizer.authorize_command(LifecycleSupport.command(clock), bot)
    clock.now += 55.minutes
    oauth.fail_with(Slack::Auth::ContractError.new(:unknown_remote_outcome))

    2.times do
      expect_raises(Slack::Auth::ContractError) do
        authorizer.authorize_command(LifecycleSupport.command(clock), bot)
      end.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    end
    expect_raises(Slack::Auth::ContractError) { context.dispatch("POST", "chat.postMessage") }
      .code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    oauth.requests.size.should eq(2)
    api.requests.should be_empty
  end
end
