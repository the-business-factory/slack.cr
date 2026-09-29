# One page of `conversations.replies`. The first message of the first page is
# the thread parent.
struct Slack::Models::ConversationsReplies < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer \
    messages : Array(Message),
    has_more : Bool
end
