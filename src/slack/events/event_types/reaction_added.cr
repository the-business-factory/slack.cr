class Slack::Events::ReactionAdded < Slack::Event
  json_record ReactionItem, ts : String, type : String, channel : String

  property item : ReactionItem,
    item_user : String,
    reaction : String,
    user : String,
    event_ts : String
end
