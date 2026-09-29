require "json"

module Slack::Models::Conversations
  # The `conversations.leave` response. `not_in_channel?` is true when the
  # caller was not a member of the conversation.
  #
  # Slack sends this flag with `"ok": true` or, as the method reference shows,
  # with `"ok": false` and no `error`. `Client#call` returns both forms.
  struct LeaveResponse
    include JSON::Serializable
    include Slack::Api::Envelope

    getter? not_in_channel : Bool = false

    # Slack answers `{"ok": false, "not_in_channel": true}` for a caller that
    # is not a member. That is an outcome, not a failure.
    def flagged_outcome? : Bool
      not_in_channel?
    end
  end
end
