# One page of `conversations.history`. `Client#each_page` reads the next cursor.
struct Slack::Models::ConversationsHistory < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer \
    messages : Array(Message),
    has_more : Bool,
    pin_count : Int32? = nil
end
