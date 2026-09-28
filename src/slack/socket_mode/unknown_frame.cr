# A frame that is not a hello, a disconnect, or an envelope. It has no
# `envelope_id`, so Slack expects no acknowledgment.
struct Slack::SocketMode::UnknownFrame
  getter type : String?
  getter raw : JSON::Any

  def initialize(@type : String?, @raw : JSON::Any)
  end
end
