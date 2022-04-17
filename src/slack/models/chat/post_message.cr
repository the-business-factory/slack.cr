struct Slack::Models::Chat::PostMessage < Slack::Model
  properties_with_initializer \
    ok : Bool,
    channel : String?,
    message : JSON::Any,
    ts : String
end
