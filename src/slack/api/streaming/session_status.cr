# The state of an agent session, for `chat.stopStream` and `agents.sessions.setStatus`.
# Slack's default on `chat.stopStream` is `Active`.
enum Slack::Api::Streaming::SessionStatus
  Active
  Processing
  Suspended
  Closed

  def wire_value : String
    case self
    in .active?     then "active"
    in .processing? then "processing"
    in .suspended?  then "suspended"
    in .closed?     then "closed"
    end
  end
end
