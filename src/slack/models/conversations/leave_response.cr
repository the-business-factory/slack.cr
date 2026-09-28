require "json"

module Slack::Models::Conversations
  # The `conversations.leave` response. `not_in_channel?` is true when the
  # caller was not a member of the conversation.
  #
  # The method reference also shows this flag with `"ok": false` and no
  # `error`. `Client#call` raises that form as `Api::Error` with the code
  # `unknown_error`.
  struct LeaveResponse
    include JSON::Serializable

    getter? not_in_channel : Bool = false
  end
end
