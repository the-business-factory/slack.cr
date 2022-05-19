struct Slack::Events::Message::FileShare < Slack::Event
  include Slack::Events::MessageSubtype

  property \
    blocks : Array(JSON::Any)?,
    files : Array(JSON::Any),
    text : String?,
    user : String
end
