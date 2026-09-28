# A thread got a reply. `message` is the parent message.
#
# Slack documents that the Events API can send this event without its
# `subtype`; that event decodes as `Slack::Events::Message`. Check
# `Message#thread_ts` to find replies.
# https://docs.slack.dev/reference/events/message/message_replied
struct Slack::Events::Message::MessageReplied < Slack::Event
  include Slack::Events::MessageSubtype

  property message : Slack::EventData::MessageSubset

  property? hidden = false
end
