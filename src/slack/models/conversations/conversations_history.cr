struct Slack::Models::ConversationsHistory < Slack::Model
  json_record ResponseMetadata, cursor : String

  json_record MessageHistory,
    blocks : Array(Hash(String, JSON::Any))?,
    files : Array(Hash(String, JSON::Any))?,
    latest_reply : String?,
    reply_count : Int32?,
    reply_users : Array(String)?,
    reply_users_count : Int32?,
    text : String?,
    thread_ts : String,
    ts : String,
    type : String,
    user : String?

  properties_with_initializer \
    messages : Array(MessageHistory),
    has_more : Bool,
    pin_count : Int32,
    response_metadata : ResponseMetadata?
end
