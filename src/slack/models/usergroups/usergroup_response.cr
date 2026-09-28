require "json"

module Slack::Models::Usergroups
  # A response with one `usergroup` object, from `usergroups.create`,
  # `usergroups.update`, and `usergroups.users.update`.
  struct UsergroupResponse
    include JSON::Serializable

    getter usergroup : Slack::Models::Usergroup
  end
end
