require "json"

module Slack::Api
  # One suggested prompt: a short *title* that the user sees and the *message*
  # that Slack sends when the user selects it.
  # See https://docs.slack.dev/reference/methods/assistant.threads.setSuggestedPrompts.
  struct SuggestedPrompt
    include JSON::Serializable
    include UI::ValueValidation

    getter title : String
    getter message : String

    # Raises `UI::ValidationError` when the title or message is blank.
    def initialize(@title : String, @message : String)
      validate!
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @title.blank?
        issues << UI::ValidationIssue.new("suggested_prompt.title.blank", "title", "Prompt title must not be blank.")
      end
      if @message.blank?
        issues << UI::ValidationIssue.new("suggested_prompt.message.blank", "message", "Prompt message must not be blank.")
      end
      issues
    end

    # `from_json` skips the checked initializer, so check the fields again before writing them.
    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "title", @title
        json.field "message", @message
      end
    end
  end
end
