require "json"

module Slack::Models::Agents
  # The new title that `agents.sessions.rename` returns.
  struct SessionTitle
    include JSON::Serializable
    include Slack::Api::Envelope

    getter title : String
  end
end
