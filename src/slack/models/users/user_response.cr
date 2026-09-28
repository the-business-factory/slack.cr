require "json"

module Slack::Models::Users
  # A response with one `user` object, from `users.info` and `users.lookupByEmail`.
  struct UserResponse
    include JSON::Serializable

    getter user : Slack::Models::User
  end
end
