require "json"
require "./user_profile"

module Slack::Models
  # A Slack user. See https://docs.slack.dev/reference/objects/user-object.
  #
  # Only `id` and `profile` are always present. Flags that Slack omits read as
  # false. `locale` is present only when the request sets `include_locale`.
  # Unknown fields are ignored.
  struct User
    include JSON::Serializable

    getter id : String
    getter team_id : String?
    getter name : String?
    getter real_name : String?
    getter tz : String?
    getter locale : String?
    getter? deleted : Bool = false
    getter? is_bot : Bool = false
    getter? is_admin : Bool = false
    getter? is_owner : Bool = false
    getter profile : UserProfile
  end
end
