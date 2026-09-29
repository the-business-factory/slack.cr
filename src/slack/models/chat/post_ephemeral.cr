# The timestamp of an ephemeral message. It cannot be used to update the message.
struct Slack::Models::Chat::PostEphemeral < Slack::Model
  include Slack::Api::Envelope
  getter message_ts : String
end
