require "json"

module Slack::Models::Agents
  # The agent session that `agents.sessions.setStatus` changed.
  #
  # `status` is the session status for all agents; `agent_status` is the status
  # of the calling agent. Both are Slack strings such as `"processing"`, so a
  # new Slack value does not make a successful call fail to decode.
  struct Session
    include JSON::Serializable
    include Slack::Api::Envelope

    getter status : String
    getter agent_status : String
    getter title : String?
  end
end
