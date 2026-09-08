require "spec"
require "file_utils"
require "../../../src/slack/auth/storage/memory_installation_store"
require "./clock"

module StorageSupport
  def self.key(team : String = "T1") : Slack::Auth::InstallationKey
    Slack::Auth::InstallationKey.new("A1", :workspace, team_id: team)
  end

  def self.grant(subject : String = "B1", token : String = "access") : Slack::Auth::Grant
    Slack::Auth::Grant.new(subject, Slack::Auth::Secret.new(token), ["read"],
      Time.utc(2027, 1, 1), Slack::Auth::Secret.new("refresh-#{token}"))
  end

  def self.query(user : String? = nil) : Slack::Auth::InstallationQuery
    Slack::Auth::InstallationQuery.new(key, user ? Slack::Auth::GrantKey.new(:user, user) : Slack::Auth::GrantKey.new(:bot))
  end

  def self.seed(store : Slack::Auth::InstallationStore) : Slack::Auth::InstallationRecord
    store.store(key, Slack::Auth::InstallationPatch.new(bot: grant("B1", "bot-access"),
      users: {"U1" => grant("U1", "user1-access"), "U2" => grant("U2", "user2-access")},
      webhook: Slack::Auth::IncomingWebhook.new(Slack::Auth::Secret.new("synthetic-webhook"), "C1")), nil)
  end

  def self.failure(code : Slack::Auth::ErrorCode, & : ->) : Nil
    error = expect_raises(Slack::Auth::ContractError) { yield }
    error.code.should eq(code)
  end

  # Adapters supply a factory accepting this authoritative clock. Each example
  # gets a fresh directory/store; production adapters can use the same matrix.
  macro conformance(name, factory)
    describe {{ name }} do
      clock = StorageSupport::Clock.new
      directory = ""
      store : Slack::Auth::InstallationStore = Slack::Auth::MemoryInstallationStore.new

      before_each do
        clock = StorageSupport::Clock.new
        directory = File.tempname("installation-conformance")
        store = {{ factory }}.call(clock, directory)
      end

      after_each do
        FileUtils.rm_rf(directory) if Dir.exists?(directory)
      end

      it "dispatches explicit users independently of actor metadata through replacement and invalidation" do
        original = StorageSupport.seed(store)
        bot = store.acquire(StorageSupport.query)
        user1 = store.acquire(StorageSupport.query("U1"))
        user2_query = Slack::Auth::InstallationQuery.new(StorageSupport.key,
          Slack::Auth::GrantKey.new(:user, "U2"), actor_user_id: "U1")
        user2 = store.acquire(user2_query)
        store.credential_for_dispatch(bot).value.should eq("bot-access")
        store.credential_for_dispatch(user1).value.should eq("user1-access")
        store.credential_for_dispatch(user2).value.should eq("user2-access")
        original.bot.should_not(be_nil).grant.refresh_token.should_not(be_nil).value.should eq("refresh-bot-access")
        original.users["U1"].grant.refresh_token.should_not(be_nil).value.should eq("refresh-user1-access")
        original.users["U2"].grant.refresh_token.should_not(be_nil).value.should eq("refresh-user2-access")

        changed = store.store(StorageSupport.key,
          Slack::Auth::InstallationPatch.new(users: {"U1" => StorageSupport.grant("U1", "replacement-user1")}), original.version)
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(user1) }
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("replacement-user1")
        store.credential_for_dispatch(user2).value.should eq("user2-access")
        store.credential_for_dispatch(bot).value.should eq("bot-access")

        store.invalidate(StorageSupport.key, Slack::Auth::GrantKey.new(:user, "U2"), changed.version)
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(user2) }
        StorageSupport.failure(:missing_grant) { store.acquire(user2_query) }
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("replacement-user1")
        store.credential_for_dispatch(bot).value.should eq("bot-access")
        StorageSupport.failure(:missing_grant) { store.acquire(StorageSupport.query("missing")) }
      end

      it "uses the complete tenant key without actor or visible-team fallback" do
        tenants = [
          StorageSupport.key,
          StorageSupport.key("T2"),
          Slack::Auth::InstallationKey.new("A2", :workspace, team_id: "T1"),
          Slack::Auth::InstallationKey.new("A1", :workspace, enterprise_id: "E1", team_id: "T1"),
          Slack::Auth::InstallationKey.new("A1", :workspace, enterprise_id: "E2", team_id: "T1"),
          Slack::Auth::InstallationKey.new("A1", :organization, enterprise_id: "E1"),
          Slack::Auth::InstallationKey.new("A1", :organization, enterprise_id: "E2"),
        ]
        tenants.each_with_index do |owner, index|
          store.store(owner, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B1", "tenant-#{index}")), nil)
        end
        tenants.each_with_index do |owner, index|
          query = Slack::Auth::InstallationQuery.new(owner, Slack::Auth::GrantKey.new(:bot),
            actor_user_id: "U1", visible_team_id: "T2")
          store.fetch(owner).should_not(be_nil).key.should eq(owner)
          store.credential_for_dispatch(store.acquire(query)).value.should eq("tenant-#{index}")
        end
        StorageSupport.failure(:missing_installation) do
          store.acquire(Slack::Auth::InstallationQuery.new(StorageSupport.key("missing"),
            Slack::Auth::GrantKey.new(:bot), visible_team_id: "T1"))
        end
      end

      it "copies caller patch inputs and returned user maps and scope arrays" do
        scopes = ["search:read"]
        user = Slack::Auth::Grant.new("U1", Slack::Auth::Secret.new("snapshot-user"), scopes)
        users = {"U1" => user}
        patch = Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B1", "snapshot-bot"), users: users)
        scopes.clear
        users.clear
        patch.users.clear
        first = store.store(StorageSupport.key, patch, nil)
        first.users["U1"].grant.scopes.clear
        first.bot.should_not(be_nil).grant.scopes.clear
        first.users.clear
        fetched = store.fetch(StorageSupport.key).should_not(be_nil)
        fetched.users["U1"].grant.scopes.clear
        fetched.users.clear
        current = store.fetch(StorageSupport.key).should_not(be_nil)
        current.users["U1"].grant.scopes.should eq(["search:read"])
        current.bot.should_not(be_nil).grant.scopes.should eq(["read"])
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("snapshot-user")
        store.credential_for_dispatch(store.acquire(StorageSupport.query)).value.should eq("snapshot-bot")
      end

      it "preserves omitted values and checks both version fields" do
        old = StorageSupport.seed(store)
        changed = store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new(users: {"U1" => StorageSupport.grant("U1", "new")}), old.version)
        changed.users["U2"].should eq(old.users["U2"])
        changed.bot.should eq(old.bot)
        changed.webhook.should eq(old.webhook)
        changed.users["U1"].revision.should be > old.users["U1"].revision
        StorageSupport.failure(:conflict) { store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new, nil) }
        StorageSupport.failure(:conflict) { store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new, old.version) }
        StorageSupport.failure(:conflict) do
          store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new, Slack::Auth::Version.new(999_i64, changed.version.revision))
        end
      end

      it "retains tombstones and prevents stale credentials after reinstall" do
        old = StorageSupport.seed(store)
        reference = store.acquire(StorageSupport.query)
        lease = store.claim_refresh(reference, 1.minute)
        store.mark_refresh_dispatched(lease)
        deleted = store.delete(StorageSupport.key, old.version)
        deleted.deleted?.should be_true
        deleted.bot.should be_nil
        deleted.users.should be_empty
        deleted.webhook.should be_nil
        deleted.version.generation.should be > old.version.generation
        StorageSupport.failure(:conflict) { store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new, nil) }
        fresh = store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B1", "fresh")), deleted.version)
        fresh.version.generation.should be > deleted.version.generation
        fresh.version.revision.should be > deleted.version.revision
        fresh.users.should be_empty
        StorageSupport.failure(:conflict) { store.complete_refresh(lease, StorageSupport.grant) }
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(reference) }
        StorageSupport.failure(:conflict) { store.delete(StorageSupport.key, old.version) }
      end

      it "rejects repeated deletion and invalidation without changing retained state" do
        old = StorageSupport.seed(store)
        other = StorageSupport.key("T2")
        unrelated = store.store(other, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B2", "other"),
          users: {"U3" => StorageSupport.grant("U3", "other-user")}), nil)
        other_query = Slack::Auth::InstallationQuery.new(other, Slack::Auth::GrantKey.new(:user, "U3"))
        lease = store.claim_refresh(store.acquire(other_query), 1.minute)
        deleted = store.delete(StorageSupport.key, old.version)

        [old.version, deleted.version].each do |expected|
          code = expected == deleted.version ? Slack::Auth::ErrorCode::MissingInstallation : Slack::Auth::ErrorCode::Conflict
          StorageSupport.failure(code) { store.delete(StorageSupport.key, expected) }
          store.fetch(StorageSupport.key).should eq(deleted)
          store.fetch(other).should eq(unrelated)
          store.refresh_status(other_query).should_not(be_nil).lease.should eq(lease)

          StorageSupport.failure(code) { store.invalidate(StorageSupport.key, Slack::Auth::GrantKey.new(:bot), expected) }
          store.fetch(StorageSupport.key).should eq(deleted)
          store.fetch(other).should eq(unrelated)
          store.refresh_status(other_query).should_not(be_nil).lease.should eq(lease)
        end
        store.credential_for_dispatch(lease.credential).value.should eq("other-user")
      end

      it "rejects deletion and invalidation of never-stored keys without creating records" do
        old = StorageSupport.seed(store)
        missing = StorageSupport.key("missing")
        StorageSupport.failure(:missing_installation) { store.delete(missing, old.version) }
        store.fetch(missing).should be_nil
        store.fetch(StorageSupport.key).should eq(old)
        StorageSupport.failure(:missing_installation) { store.invalidate(missing, Slack::Auth::GrantKey.new(:bot), old.version) }
        store.fetch(missing).should be_nil
        store.fetch(StorageSupport.key).should eq(old)
      end

      it "coordinates each grant independently and preserves unrelated updates during completion" do
        initial = StorageSupport.seed(store)
        bot = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
        user1 = store.claim_refresh(store.acquire(StorageSupport.query("U1")), 1.minute)
        user2 = store.claim_refresh(store.acquire(StorageSupport.query("U2")), 1.minute)
        StorageSupport.failure(:refresh_busy) { store.claim_refresh(bot.credential, 1.minute) }
        store.mark_refresh_dispatched(bot)
        StorageSupport.failure(:refresh_busy) { store.credential_for_dispatch(bot.credential) }
        updated = store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new(users: {"U1" => StorageSupport.grant("U1", "updated")}), initial.version)
        completed = store.complete_refresh(bot, StorageSupport.grant("B1", "rotated"))
        completed.users["U1"].should eq(updated.users["U1"])
        store.credential_for_dispatch(store.acquire(StorageSupport.query)).value.should eq("rotated")
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("updated")
        store.credential_for_dispatch(user2.credential).value.should eq("user2-access")
        store.refresh_status(StorageSupport.query("U2")).should_not(be_nil).lease.should eq(user2)
        StorageSupport.failure(:conflict) { store.mark_refresh_dispatched(user1) }
        StorageSupport.failure(:conflict) { store.complete_refresh(bot, StorageSupport.grant) }
        store.mark_refresh_dispatched(user2)
        expiry = clock.now + 30.seconds
        replacement = Slack::Auth::Grant.new("U2", Slack::Auth::Secret.new("user-rotated"),
          ["search:read", "chat:write"], expiry, Slack::Auth::Secret.new("next-user-refresh"))
        users_completed = store.complete_refresh(user2, replacement)
        store.fetch(StorageSupport.key).should_not(be_nil).users["U2"].grant.should eq(replacement)
        rotated = users_completed.users["U2"].grant
        rotated.refresh_token.should_not(be_nil).value.should eq("next-user-refresh")
        rotated.scopes.should eq(["search:read", "chat:write"])
        rotated.expires_at.should eq(expiry)
        users_completed.users["U1"].should eq(updated.users["U1"])
        users_completed.bot.should eq(completed.bot)
        reference = store.acquire(StorageSupport.query("U2"))
        store.credential_for_dispatch(reference).value.should eq("user-rotated")
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(user2.credential) }
        clock.now = expiry
        StorageSupport.failure(:reauthorization_required) { store.credential_for_dispatch(reference) }
        next_lease = store.claim_refresh(reference, 1.minute)
        next_lease.fence.should be > user2.fence
        store.mark_refresh_dispatched(next_lease)
        next_replacement = StorageSupport.grant("U2", "second-user-rotation")
        next_record = store.complete_refresh(next_lease, next_replacement)
        store.fetch(StorageSupport.key).should_not(be_nil).users["U2"].grant.should eq(next_replacement)
        next_record.users["U2"].grant.refresh_token.should_not(be_nil).value.should eq("refresh-second-user-rotation")
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U2"))).value.should eq("second-user-rotation")
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("updated")
        store.credential_for_dispatch(store.acquire(StorageSupport.query)).value.should eq("rotated")
        StorageSupport.failure(:conflict) { store.complete_refresh(user2, replacement) }
      end

      it "preserves completed rotation against stale targeted revocation and deletion" do
        old = StorageSupport.seed(store)
        bot = store.acquire(StorageSupport.query)
        user = store.acquire(StorageSupport.query("U2"))
        lease = store.claim_refresh(user, 1.minute)
        store.mark_refresh_dispatched(lease)
        completed = store.complete_refresh(lease, StorageSupport.grant("U2", "completed-user"))
        StorageSupport.failure(:conflict) do
          store.invalidate(StorageSupport.key, Slack::Auth::GrantKey.new(:user, "U2"), old.version)
        end
        StorageSupport.failure(:conflict) { store.delete(StorageSupport.key, old.version) }
        store.fetch(StorageSupport.key).should eq(completed)
        store.refresh_status(StorageSupport.query("U2")).should be_nil
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(user) }
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U2"))).value.should eq("completed-user")
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U1"))).value.should eq("user1-access")
        store.credential_for_dispatch(bot).value.should eq("bot-access")
      end

      it "recovers only an expired owner which never durably dispatched" do
        StorageSupport.seed(store)
        reference = store.acquire(StorageSupport.query)
        old = store.claim_refresh(reference, 1.second)
        clock.now += 1.second
        fresh = store.claim_refresh(reference, 1.minute)
        fresh.fence.should be > old.fence
        StorageSupport.failure(:conflict) { store.mark_refresh_dispatched(old) }
        store.mark_refresh_dispatched(fresh)
        clock.now += 1.minute
        store.refresh_status(StorageSupport.query).should_not(be_nil).phase.uncertain?.should be_true
        StorageSupport.failure(:unknown_remote_outcome) { store.claim_refresh(reference, 1.minute) }
        StorageSupport.failure(:unknown_remote_outcome) { store.credential_for_dispatch(reference) }
        StorageSupport.failure(:conflict) { store.complete_refresh(fresh, StorageSupport.grant) }
        StorageSupport.failure(:conflict) { store.release_refresh(fresh) }
      end

      it "quarantines uncertain outcomes until authorization replaces the grant" do
        old = StorageSupport.seed(store)
        lease = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
        store.mark_refresh_dispatched(lease)
        store.fail_refresh(lease, :unknown_remote_outcome)
        StorageSupport.failure(:unknown_remote_outcome) { store.credential_for_dispatch(lease.credential) }
        store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B1", "authorized")), old.version)
        store.refresh_status(StorageSupport.query).should be_nil
        StorageSupport.failure(:conflict) { store.complete_refresh(lease, StorageSupport.grant) }
      end

      it "removes only a rejected grant and rejects stale completion after invalidation" do
        old = StorageSupport.seed(store)
        bot = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
        user = store.claim_refresh(store.acquire(StorageSupport.query("U1")), 1.minute)
        store.mark_refresh_dispatched(bot)
        store.mark_refresh_dispatched(user)
        invalid = store.invalidate(StorageSupport.key, Slack::Auth::GrantKey.new(:bot), old.version)
        invalid.users.should eq(old.users)
        StorageSupport.failure(:conflict) { store.complete_refresh(bot, StorageSupport.grant) }
        store.fail_refresh(user, :rejected)
        current = store.fetch(StorageSupport.key).should_not(be_nil)
        current.users.has_key?("U1").should be_false
        current.users["U2"].should eq(old.users["U2"])
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(user.credential) }
        StorageSupport.failure(:conflict) { store.credential_for_dispatch(bot.credential) }
        store.credential_for_dispatch(store.acquire(StorageSupport.query("U2"))).value.should eq("user2-access")
      end

      it "rejects wrong subjects, wrong lease fields and invalid durations" do
        StorageSupport.seed(store)
        reference = store.acquire(StorageSupport.query)
        StorageSupport.failure(:invalid_configuration) { store.claim_refresh(reference, Time::Span.zero) }
        lease = store.claim_refresh(reference, 1.minute)
        StorageSupport.failure(:conflict) { store.complete_refresh(lease, StorageSupport.grant) }
        forged = Slack::Auth::RefreshLease.new(reference, lease.fence + 1, lease.expires_at)
        StorageSupport.failure(:conflict) { store.mark_refresh_dispatched(forged) }
        store.mark_refresh_dispatched(lease)
        StorageSupport.failure(:invalid_identity) { store.complete_refresh(lease, StorageSupport.grant("wrong")) }
        store.complete_refresh(lease, StorageSupport.grant("B1", "valid"))
      end

      it "releases unsent ownership and rejects missing or nonrotating grants" do
        original = StorageSupport.seed(store)
        lease = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
        store.release_refresh(lease)
        store.refresh_status(StorageSupport.query).should be_nil
        next_lease = store.claim_refresh(lease.credential, 1.minute)
        next_lease.fence.should be > lease.fence
        StorageSupport.failure(:conflict) { store.mark_refresh_dispatched(lease) }
        StorageSupport.failure(:missing_grant) do
          store.invalidate(StorageSupport.key, Slack::Auth::GrantKey.new(:user, "absent"), original.version)
        end
        nonrotating = Slack::Auth::Grant.new("B1", Slack::Auth::Secret.new("long-lived"), ["read"])
        store.store(StorageSupport.key, Slack::Auth::InstallationPatch.new(bot: nonrotating), original.version)
        reference = store.acquire(StorageSupport.query)
        StorageSupport.failure(:reauthorization_required) { store.claim_refresh(reference, 1.minute) }
        store.credential_for_dispatch(reference).value.should eq("long-lived")
      end

      it "checks expiry at the dispatch boundary but permits a refresh reference" do
        StorageSupport.seed(store)
        reference = store.acquire(StorageSupport.query)
        clock.now = Time.utc(2027, 1, 1)
        StorageSupport.failure(:reauthorization_required) { store.credential_for_dispatch(reference) }
        store.claim_refresh(reference, 1.minute)
      end

      it "admits one fiber owner with barriers and bounded completion" do
        StorageSupport.seed(store)
        reference = store.acquire(StorageSupport.query)
        ready = Channel(Nil).new(2)
        start = Channel(Nil).new(2)
        results = Channel(Slack::Auth::RefreshLease | Slack::Auth::ErrorCode).new(2)
        # Two fibers announce readiness, await release, then return one result.
        # The parent joins both results before closing every channel.
        2.times do
          spawn do
            ready.send(nil)
            start.receive
            begin
              results.send(store.claim_refresh(reference, 1.minute))
            rescue error : Slack::Auth::ContractError
              results.send(error.code)
            end
          end
        end
        begin
          2.times do
            select
            when ready.receive
            when timeout(5.seconds)
              fail "fiber readiness timed out"
            end
          end
          2.times { start.send(nil) }
          owners = 0
          busy = 0
          2.times do
            select
            when result = results.receive
              if result.is_a?(Slack::Auth::RefreshLease)
                owners += 1
              else
                result.should eq(Slack::Auth::ErrorCode::RefreshBusy)
                busy += 1
              end
            when timeout(5.seconds)
              fail "fiber completion timed out"
            end
          end
          owners.should eq(1)
          busy.should eq(1)
        ensure
          ready.close
          start.close
          results.close
        end
      end
    end
  end
end
