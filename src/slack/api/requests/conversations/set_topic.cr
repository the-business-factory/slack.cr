require "json"

module Slack::Api
  # Sets the topic of a conversation and returns the changed conversation.
  # See https://docs.slack.dev/reference/methods/conversations.setTopic.
  #
  # Slack shows *topic* as plain text, without formatting or links. An empty
  # topic clears it.
  struct ConversationsSetTopic < Request(Models::Conversation)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter topic : String

    def initialize(@channel : String, @topic : String)
    end

    def method_path : String
      "conversations.setTopic"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ConversationChecks.text_issues(issues, "conversations_set_topic", "topic", @topic)
      issues
    end
  end
end
