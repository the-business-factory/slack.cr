require "json"

module Slack::Api
  # Sets the description (purpose) of a conversation. An empty purpose clears it.
  # See https://docs.slack.dev/reference/methods/conversations.setPurpose.
  struct ConversationsSetPurpose < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter purpose : String

    def initialize(@channel : String, @purpose : String)
    end

    def method_path : String
      "conversations.setPurpose"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ConversationChecks.text_issues(issues, "conversations_set_purpose", "purpose", @purpose)
      issues
    end
  end
end
