# A user unpinned an item from the channel. The item stays raw JSON.
# https://docs.slack.dev/reference/events/message/unpinned_item
struct Slack::Events::Message::UnpinnedItem < Slack::Event
  include Slack::Events::MessageSubtype

  property item : JSON::Any, item_type : String, text : String, user : String
end
