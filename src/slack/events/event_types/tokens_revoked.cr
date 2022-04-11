class Slack::Events::TokensRevoked < Slack::Event
  property tokens : JSON::Any, event_ts : String
end
