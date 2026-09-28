require "json"

module Slack::Models::Auth
  # A workspace that an org-wide app is approved for, from `auth.teams.list`.
  # `icon` is present only when the request sets `include_icon`, and stays raw JSON.
  struct Team
    include JSON::Serializable

    getter id : String
    getter name : String
    getter icon : JSON::Any?
  end
end
