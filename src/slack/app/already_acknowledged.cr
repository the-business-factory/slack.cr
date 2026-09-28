# Raised when a listener calls `ack` after the request already has a response:
# a second `ack`, or an `ack` after the acknowledgment deadline passed.
class Slack::App::AlreadyAcknowledged < Exception
  def initialize
    super("The request is already acknowledged")
  end
end
