require "json"

module Slack::Api
  # Adds an emoji reaction to a message. See https://docs.slack.dev/reference/methods/reactions.add.
  #
  # *name* is the emoji name without colons. Slack answers `already_reacted`
  # when the token's user already added this reaction.
  struct ReactionsAdd < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter name : String
    getter timestamp : String

    def initialize(@channel : String, @name : String, @timestamp : String)
    end

    def method_path : String
      "reactions.add"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @name.empty?
        issues << UI::ValidationIssue.new("reactions.name.empty", "name", "Reaction name must not be empty.")
      end
      issues
    end
  end
end
