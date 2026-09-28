# One page of `conversations.replies`. The first message of the first page is
# the thread parent.
struct Slack::Models::ConversationsReplies < Slack::Model
  properties_with_initializer \
    messages : Array(ConversationsHistory::MessageHistory),
    has_more : Bool
end
