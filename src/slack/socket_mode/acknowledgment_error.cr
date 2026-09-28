# Raised when an `Acknowledger` cannot send an acknowledgment: the envelope is
# already acknowledged, it does not accept a response payload, or the client
# has stopped.
class Slack::SocketMode::AcknowledgmentError < Exception
end
