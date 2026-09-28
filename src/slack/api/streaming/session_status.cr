# The session state that `chat.stopStream` records. Slack's default is `Active`.
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
