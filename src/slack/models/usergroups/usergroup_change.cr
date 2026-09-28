require "json"

module Slack::Models::Usergroups
  # The response of `usergroups.enable` and `usergroups.disable`. Slack documents
  # `usergroup` as optional in these responses.
  struct UsergroupChange
    include JSON::Serializable

    getter usergroup : Slack::Models::Usergroup?
  end
end
