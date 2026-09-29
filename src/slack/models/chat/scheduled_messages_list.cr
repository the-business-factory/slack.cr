# One page of `chat.scheduledMessages.list`.
struct Slack::Models::Chat::ScheduledMessagesList < Slack::Model
  include Slack::Api::Envelope
  getter scheduled_messages : Array(Slack::Models::Chat::ScheduledMessage)
end
