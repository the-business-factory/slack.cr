struct Slack::Events::AppHomeOpened < Slack::Event
  property channel : String,
    tab : String,
    user : String
end
