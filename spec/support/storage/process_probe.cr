require "webmock"
require "./durable_store"
require "./file_clock"
require "./process_helpers"

directory, action, identity = ARGV
store = StorageSupport::DurableStore.new(directory, StorageSupport::FileClock.new(File.join(directory, "clock")))
key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot))
# All contenders capture the same parent-supplied version before readiness.
# The parent releases them together, then joins each child with a deadline.
expected = Slack::Auth::Version.from_json(File.read(File.join(directory, "expected.json"))) if action == "mutate"
completion = Slack::Auth::RefreshLease.from_json(File.read(File.join(directory, "completion.json"))) if action == "mutate" && identity == "complete"
File.write(File.join(directory, "ready-#{identity}"), "ready")
StorageSupport.await_file(File.join(directory, "start-#{identity}"))
if expected
  begin
    case identity
    when "store-one", "store-two"
      replacement = Slack::Auth::Grant.new("U1", Slack::Auth::Secret.new(identity), ["search:read"])
      store.store(key, Slack::Auth::InstallationPatch.new(users: {"U1" => replacement}), expected)
    when "complete"
      raise "missing completion lease" unless completion
      replacement = Slack::Auth::Grant.new("U1", Slack::Auth::Secret.new("process-rotated"),
        ["search:read"], Time.utc(2027, 1, 1), Slack::Auth::Secret.new("process-refresh"))
      store.complete_refresh(completion, replacement)
    when "invalidate"
      store.invalidate(key, Slack::Auth::GrantKey.new(:user, "U1"), expected)
    when "delete"
      store.delete(key, expected)
    else
      raise "unknown mutation probe"
    end
    File.write(File.join(directory, "result-#{identity}"), identity)
  rescue error : Slack::Auth::ContractError
    File.write(File.join(directory, "result-#{identity}"), error.code.to_s)
  end
  exit
end
if action == "read"
  token = store.credential_for_dispatch(store.acquire(query))
  File.write(File.join(directory, "result-#{identity}"), token.value)
  exit
end

begin
  lease = store.claim_refresh(store.acquire(query), 10.seconds)
  store.mark_refresh_dispatched(lease) if action == "dispatched"
  File.write(File.join(directory, "lease-#{identity}"), lease.to_json)
  File.write(File.join(directory, "result-#{identity}"), "acquired")
  # Crash tests stop here after durable state and the result barrier are visible.
  if action != "claim"
    sleep 10.seconds
    raise "crash controller did not stop the probe"
  end
rescue error : Slack::Auth::ContractError
  File.write(File.join(directory, "result-#{identity}"), error.code.to_s)
end
