class Slack::Events::ReactionAdded < Slack::Event
  struct ReactionItem
    include JSON::Serializable
    property ts : String, type : String, channel : String
  end

  property item : ReactionItem,
    item_user : String,
    reaction : String,
    user : String,
    event_ts : String
end
