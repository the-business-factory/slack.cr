require "../../../src/slack/auth/credential_lifecycle"
require "../../../src/slack/auth/storage/memory_installation_store"

# Offline public-require smoke test. This fixture is an executable, not spec support.
Slack.configure { |settings| settings.signing_secret = "synthetic-consumer-secret" }
store = Slack::Auth::MemoryInstallationStore.new
key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
store.store(key, Slack::Auth::InstallationPatch.new, nil)
service = Slack::Auth::CredentialLifecycle.new("A1", store)
body = File.read("spec/fixtures/credential_lifecycle/app_uninstalled.json")
timestamp = Time.utc.to_unix.to_s
request = HTTP::Request.new("POST", "/events", HTTP::Headers{
  "X-Slack-Request-Timestamp" => timestamp,
  "X-Slack-Signature"         => Slack::Webhooks::Signature.new(timestamp, body).compute,
}, body)
delivery : Slack::Auth::PreparedLifecycleDelivery = service.prepare(request)
outcome : Slack::Auth::LifecycleOutcome = service.apply(delivery)
raise "uninstall failed" unless outcome.applied?
