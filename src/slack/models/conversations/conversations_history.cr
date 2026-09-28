# One page of `conversations.history`. `Client#each_page` reads the next cursor.
struct Slack::Models::ConversationsHistory < Slack::Model
  json_record MessageHistory,
    blocks : Array(Hash(String, JSON::Any))? = nil,
    files : Array(Hash(String, JSON::Any))? = nil,
    latest_reply : String? = nil,
    reply_count : Int32? = nil,
    reply_users : Array(String)? = nil,
    reply_users_count : Int32? = nil,
    subtype : String? = nil,
    text : String? = nil,
    thread_ts : String? = nil,
    ts : String,
    type : String,
    user : String? = nil

  properties_with_initializer \
    messages : Array(MessageHistory),
    has_more : Bool,
    pin_count : Int32? = nil
end
