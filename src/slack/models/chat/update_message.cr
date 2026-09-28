# Updated message identity and fallback, with optional unmodeled message data.
struct Slack::Models::Chat::UpdateMessage < Slack::Model
  properties_with_initializer \
    channel : String,
    ts : String,
    text : String,
    message : JSON::Any? = nil

  property? ok = true
end
