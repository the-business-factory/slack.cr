struct Slack::Events::AppMentioned < Slack::Event
  property channel : String, user : String
end
