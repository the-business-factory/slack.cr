# A user sent a `/me` message.
# https://docs.slack.dev/reference/events/message/me_message
struct Slack::Events::Message::MeMessage < Slack::Event
  include Slack::Events::MessageSubtype

  property text : String, user : String
end
