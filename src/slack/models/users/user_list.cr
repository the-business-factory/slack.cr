require "json"

module Slack::Models::Users
  # One page of `users.list`. `Client#each_page` reads the next cursor.
  struct UserList
    include JSON::Serializable

    getter members : Array(Slack::Models::User)
    getter cache_ts : Int64?
  end
end
