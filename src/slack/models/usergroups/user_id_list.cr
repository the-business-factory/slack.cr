require "json"

module Slack::Models::Usergroups
  # The `usergroups.users.list` response: user IDs.
  struct UserIdList
    include JSON::Serializable
    include Slack::Api::Envelope

    getter users : Array(String)
  end
end
