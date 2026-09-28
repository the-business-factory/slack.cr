# The timestamp of an ephemeral message. It cannot be used to update the message.
struct Slack::Models::Chat::PostEphemeral < Slack::Model
  getter message_ts : String

  property? ok = true
end
