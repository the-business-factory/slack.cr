struct Slack::Models::Chat::PostMessage < Slack::Model
  properties_with_initializer \
    channel : String?,
    message : JSON::Any,
    ts : String

  property? ok = true
end
