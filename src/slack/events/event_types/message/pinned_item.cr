# A user pinned an item to the channel. The item stays raw JSON.
# https://docs.slack.dev/reference/events/message/pinned_item
struct Slack::Events::Message::PinnedItem < Slack::Event
  include Slack::Events::MessageSubtype

  property item : JSON::Any, item_type : String, text : String, user : String
end
