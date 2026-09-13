require "../../../src/slack/auth/rotation_service"
require "../../../src/slack/auth/storage/memory_installation_store"

# Independently compilable consumer; no spec helper, global configuration or HTTP.
class OfflineRotationTransport < Slack::Auth::Transport
  def execute(request : Slack::Auth::TransportRequest) : Slack::Auth::TransportResponse
    raise "fresh consumer grant unexpectedly attempted refresh"
  end
end

configuration = Slack::Auth::OAuthConfiguration.new(URI.parse("https://example.test/authorize"),
  URI.parse("https://example.test/token"), "synthetic-client", Slack::Auth::Secret.new("synthetic-secret"),
  URI.parse("https://example.test/callback"))
store = Slack::Auth::MemoryInstallationStore.new
key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
grant = Slack::Auth::Grant.new("B1", Slack::Auth::Secret.new("synthetic-access"), ["chat:write"],
  Time.utc + 1.hour, Slack::Auth::Secret.new("synthetic-refresh"))
store.store(key, Slack::Auth::InstallationPatch.new(bot: grant), nil)
client = Slack::Auth::RefreshClient.new(configuration, OfflineRotationTransport.new)
service = Slack::Auth::RotationService.new(store, client)
reference = service.rotate(Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:bot)))
raise "incorrect consumer credential" unless store.credential_for_dispatch(reference) == grant.access_token
