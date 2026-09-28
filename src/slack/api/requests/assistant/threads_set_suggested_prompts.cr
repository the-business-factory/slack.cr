require "json"

module Slack::Api
  # Shows up to four suggested prompts in an app thread.
  # See https://docs.slack.dev/reference/methods/assistant.threads.setSuggestedPrompts.
  #
  # Omit *thread_ts* to set the prompts for the latest message in the channel.
  # Slack says that *thread_ts* is for the legacy assistant experience only;
  # with an agent app, a call with it fails silently.
  #
  # ```
  # client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: "D123",
  #   title: "Try one of these",
  #   prompts: [Slack::Api::SuggestedPrompt.new(title: "Summarize", message: "Summarize this channel.")]))
  # ```
  struct AssistantThreadsSetSuggestedPrompts < Request(Models::DefaultResponse)
    include JsonBody

    MAX_PROMPTS = 4

    getter channel_id : String
    getter thread_ts : String?
    getter title : String?
    @prompts : Array(SuggestedPrompt)

    # Copies *prompts*, so later changes to the argument have no effect.
    def initialize(*, @channel_id : String, prompts : Enumerable(SuggestedPrompt),
                   @thread_ts : String? = nil, @title : String? = nil)
      @prompts = prompts.map(&.itself)
    end

    # A copy of the prompts.
    def prompts : Array(SuggestedPrompt)
      @prompts.dup
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @channel_id.blank?
        issues << issue("channel_id.blank", "channel_id", "Channel ID must not be blank.")
      end
      if (thread_ts = @thread_ts) && !Streaming.timestamp?(thread_ts)
        issues << issue("thread_ts.invalid", "thread_ts",
          "Thread timestamp must contain digits, a decimal point, and fractional digits.")
      end
      prompt_count_issue(issues)
      @prompts.each_with_index { |prompt, index| issues.concat(prompt.validate.map(&.at("prompts.#{index}"))) }
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "channel_id", @channel_id
        json.field "thread_ts", @thread_ts if @thread_ts
        json.field "title", @title if @title
        json.field "prompts", @prompts
      end
    end

    def method_path : String
      "assistant.threads.setSuggestedPrompts"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    private def prompt_count_issue(issues : Array(UI::ValidationIssue)) : Nil
      if @prompts.empty?
        issues << issue("prompts.empty", "prompts", "Prompts must contain at least one prompt.")
      elsif @prompts.size > MAX_PROMPTS
        issues << issue("prompts.too_many", "prompts", "Prompts cannot contain more than #{MAX_PROMPTS} prompts.")
      end
    end

    private def issue(code : String, path : String, message : String) : UI::ValidationIssue
      UI::ValidationIssue.new("assistant_threads_set_suggested_prompts.#{code}", path, message)
    end
  end
end
