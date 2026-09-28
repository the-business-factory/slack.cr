require "json"

module Slack::Api
  # Moves the read cursor of a conversation to the message at *ts*.
  # See https://docs.slack.dev/reference/methods/conversations.mark.
  struct ConversationsMark < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter ts : String

    def initialize(@channel : String, @ts : String)
    end

    def method_path : String
      "conversations.mark"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ChatChecks.timestamp_issue(issues, "conversations_mark", "ts", @ts)
      issues
    end
  end
end
