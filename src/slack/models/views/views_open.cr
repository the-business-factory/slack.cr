struct Slack::Models::ViewsOpen < Slack::Model
  properties_with_initializer view : JSON::Any

  property? ok = true
end
