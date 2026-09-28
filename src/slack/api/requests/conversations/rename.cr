require "json"

module Slack::Api
  # Renames a conversation. *name* follows the rules of `ConversationsCreate`.
  # See https://docs.slack.dev/reference/methods/conversations.rename.
  struct ConversationsRename < Request(Models::Conversation)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter name : String

    def initialize(@channel : String, @name : String)
    end

    def method_path : String
      "conversations.rename"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ConversationChecks.name_issues(issues, "conversations_rename", @name)
      issues
    end
  end
end
