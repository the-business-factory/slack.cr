require "json"

module Slack::Api
  # Removes one user from a conversation.
  # See https://docs.slack.dev/reference/methods/conversations.kick.
  #
  # Slack raises `not_in_channel` when the user is not a member, and
  # `cant_kick_self` when *user* is the caller.
  struct ConversationsKick < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter user : String

    def initialize(@channel : String, @user : String)
    end

    def method_path : String
      "conversations.kick"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
