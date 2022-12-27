struct Slack::Models::Chat::Delete < Slack::Model
  properties_with_initializer channel : String, ts : String

  property? ok = true
end
