require "json"

module Slack::Api
  # Invites users to a public or private channel.
  # See https://docs.slack.dev/reference/methods/conversations.invite.
  #
  # When one user cannot be invited, Slack raises the first error, such as
  # `user_not_found` or `already_in_channel`, and invites nobody. Set *force*
  # to invite the valid users and ignore the others.
  struct ConversationsInvite < Request(Models::Conversation)
    include JsonBody

    # The documented maximum number of *users*.
    MAX_USERS = 1000

    @users : Array(String)

    getter channel : String
    getter? force : Bool

    def initialize(@channel : String, users : Enumerable(String), *, @force : Bool = false)
      # Copy once: Array#to_a returns the caller's array itself.
      @users = users.map(&.itself)
    end

    def users : Array(String)
      @users.dup
    end

    def method_path : String
      "conversations.invite"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ConversationChecks.users_issues(issues, "conversations_invite", @users, MAX_USERS)
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "channel", @channel
        json.field "users", @users.join(',')
        json.field "force", true if @force
      end
    end
  end
end
