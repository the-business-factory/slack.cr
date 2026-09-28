# One page of `chat.scheduledMessages.list`.
struct Slack::Models::Chat::ScheduledMessagesList < Slack::Model
  getter scheduled_messages : Array(Slack::Models::Chat::ScheduledMessage)

  property? ok = true
end
