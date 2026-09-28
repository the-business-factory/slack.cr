require "json"

module Slack::Api
  # Creates a public or private channel.
  # See https://docs.slack.dev/reference/methods/conversations.create.
  #
  # Slack allows lowercase letters, numbers, hyphens, and underscores in *name*,
  # and checks them itself. A name that exists raises `Api::Error` with the code
  # `name_taken`. Org-wide apps pass *team_id* to choose the workspace.
  struct ConversationsCreate < Request(Models::Conversation)
    include JsonBody

    getter name : String
    getter? is_private : Bool
    getter team_id : String?

    def initialize(@name : String, *, @is_private : Bool = false, @team_id : String? = nil)
    end

    def method_path : String
      "conversations.create"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      ConversationChecks.name_issues(issues, "conversations_create", @name)
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "name", @name
        json.field "is_private", true if @is_private
        @team_id.try { |team_id| json.field "team_id", team_id }
      end
    end
  end
end
