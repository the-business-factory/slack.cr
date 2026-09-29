require "json"

module Slack::Models::Auth
  # One page of `auth.teams.list`. `Client#each_page` reads the next cursor.
  struct TeamsList
    include JSON::Serializable
    include Slack::Api::Envelope

    getter teams : Array(Team)
  end
end
