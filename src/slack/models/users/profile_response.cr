require "json"

module Slack::Models::Users
  # A response with one `profile` object, from `users.profile.get` and `users.profile.set`.
  struct ProfileResponse
    include JSON::Serializable

    getter profile : Slack::Models::UserProfile
  end
end
