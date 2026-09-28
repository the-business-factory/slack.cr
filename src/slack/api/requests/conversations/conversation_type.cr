module Slack::Api
  # A conversation type that `ConversationsList` can request.
  enum ConversationType
    PublicChannel
    PrivateChannel
    Mpim
    Im

    # The wire name, such as `public_channel`.
    def wire_name : String
      to_s.underscore
    end
  end
end
