require "json"

module Slack::Models::Users
  # The `users.getPresence` response.
  # See https://docs.slack.dev/reference/methods/users.getPresence.
  #
  # `presence` is `active` or `away`. Slack sends the other fields only when
  # the token's user asks for their own presence.
  struct Presence
    include JSON::Serializable

    getter presence : String
    getter online : Bool?
    getter auto_away : Bool?
    getter manual_away : Bool?
    getter connection_count : Int32?
    # Unix time of the last activity.
    getter last_activity : Int64?

    def active? : Bool
      @presence == "active"
    end
  end
end
