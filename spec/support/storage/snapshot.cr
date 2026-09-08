require "json"
require "../../../src/slack/auth/storage/memory_installation_store"

# Serialization exists only in this test harness. Production contracts do not gain
# a wire format; these files contain plaintext synthetic secrets.
{% for type in [
                 Slack::Auth::Secret,
                 Slack::Auth::InstallationKey,
                 Slack::Auth::GrantKey,
                 Slack::Auth::Grant,
                 Slack::Auth::IncomingWebhook,
                 Slack::Auth::Version,
                 Slack::Auth::StoredGrant,
                 Slack::Auth::InstallationRecord,
                 Slack::Auth::InstallationQuery,
                 Slack::Auth::CredentialReference,
                 Slack::Auth::RefreshLease,
                 Slack::Auth::RefreshOwnership,
               ] %}
  struct {{ type }}
    include JSON::Serializable
  end
{% end %}

module StorageSupport
  class Snapshot
    include JSON::Serializable
    getter records : Array(Slack::Auth::InstallationRecord)
    getter ownership : Array(Slack::Auth::RefreshOwnership)
    getter fence : Int64

    def initialize(engine : Slack::Auth::Storage::Engine)
      @records = engine.records.values
      @ownership = engine.ownership.values
      @fence = engine.fence
    end
  end
end
