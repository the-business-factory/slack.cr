# The streamed message that `chat.startStream`, `chat.appendStream`, or
# `chat.stopStream` changed. Only `chat.stopStream` returns `message`.
struct Slack::Models::Chat::StreamMessage < Slack::Model
  properties_with_initializer \
    channel : String,
    ts : String,
    message : JSON::Any? = nil

  property? ok = true
end
