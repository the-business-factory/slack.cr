struct Slack::Events::Message::ThreadBroadcast < Slack::Event
  include Slack::Events::MessageSubtype

  property root : Hash(String, JSON::Any), thread_ts : String
end
