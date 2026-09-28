# https://docs.slack.dev/reference/events/reaction_added
struct Slack::Events::ReactionAdded < Slack::Event
  # `item_user` is nil for a message that has no user author, such as an
  # incoming webhook message.
  property item : Slack::EventData::ReactionItem,
    item_user : String?,
    reaction : String,
    user : String,
    event_ts : String
end
