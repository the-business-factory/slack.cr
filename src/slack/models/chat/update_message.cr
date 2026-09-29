# Updated message identity and fallback, with optional unmodeled message data.
struct Slack::Models::Chat::UpdateMessage < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer \
    channel : String,
    ts : String,
    text : String,
    message : JSON::Any? = nil
end
