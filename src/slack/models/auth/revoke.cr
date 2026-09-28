require "json"

module Slack::Models::Auth
  # The `auth.revoke` result. `revoked?` is false in test mode.
  struct Revoke
    include JSON::Serializable

    getter? revoked : Bool
  end
end
