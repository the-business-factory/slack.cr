require "json"

module Slack::Models::Auth
  # The `auth.revoke` result. `revoked?` is false in test mode.
  struct Revoke
    include JSON::Serializable
    include Slack::Api::Envelope

    getter? revoked : Bool
  end
end
