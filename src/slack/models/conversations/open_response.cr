require "json"

module Slack::Models::Conversations
  # The `conversations.open` response.
  #
  # When the request sets `return_im`, `channel` is the full conversation: an
  # `IMChat` for a direct message or a `PrivateChannel` (`is_mpim?`) for a group
  # direct message. Otherwise it is a `ConversationRef`. `no_op?` and `already_open?`
  # are true when the conversation was open before the call.
  struct OpenResponse
    include JSON::Serializable
    include Slack::Api::Envelope

    @[JSON::Field(converter: Slack::Models::Conversations::OpenedChannelConverter)]
    getter channel : Conversation | ConversationRef
    getter? no_op : Bool = false
    getter? already_open : Bool = false

    def channel_id : String
      channel.id
    end
  end
end
