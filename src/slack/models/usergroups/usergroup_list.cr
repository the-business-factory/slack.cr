require "json"

module Slack::Models::Usergroups
  # The `usergroups.list` response.
  struct UsergroupList
    include JSON::Serializable

    getter usergroups : Array(Slack::Models::Usergroup)
  end
end
