# The root message of an assistant thread that a user started.
#
# Slack also sends this subtype inside other subtypes, such as the `message`
# of a `message_changed` event; check `EventData::MessageSubset#subtype` there.
# https://docs.slack.dev/reference/events/message/assistant_app_thread
struct Slack::Events::Message::AssistantAppThread < Slack::Event
  include Slack::Events::MessageSubtype

  property text : String?, user : String?, team : String?

  # Nil when Slack does not send it.
  property assistant_app_thread : Slack::EventData::AssistantAppThread?
end
