class Slack::Events::Message::FileShare < Slack::Events::MessageSubtype
  property \
    blocks : Array(JSON::Any)?,
    files : Array(JSON::Any),
    text : String?,
    user : String
end
