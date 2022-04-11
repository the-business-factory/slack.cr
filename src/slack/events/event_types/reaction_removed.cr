class Slack::Events::ReactionRemoved < Slack::Event
  property item : JSON::Any,
    item_user : String,
    reaction : String,
    user : String,
    event_ts : String
end
