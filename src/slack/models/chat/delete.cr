struct Slack::Models::Chat::Delete < Slack::Model
  properties_with_initializer channel : String, ok : Bool, ts : String
end
