require "json"

module Slack::Models::Apps
  # One page of `apps.event.authorizations.list`: the installations that can see
  # the event. `Client#each_page` reads the next cursor.
  struct EventAuthorizationsList
    include JSON::Serializable

    getter authorizations : Array(Slack::Events::Authorization)
  end
end
