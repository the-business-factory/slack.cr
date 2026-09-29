require "json"

module Slack::Api
  # Sets the title of an app thread.
  # See https://docs.slack.dev/reference/methods/assistant.threads.setTitle.
  #
  # Slack names `agents.sessions.rename` (`AgentsSessionsRename`) as the successor of this method.
  #
  # ```
  # client.call(Slack::Api::AssistantThreadsSetTitle.new(channel_id: "D123",
  #   thread_ts: "1724264405.531769", title: "Holidays this year"))
  # ```
  struct AssistantThreadsSetTitle < Request(Models::DefaultResponse)
    include JsonBody

    getter channel_id : String
    getter thread_ts : String
    getter title : String

    def initialize(*, @channel_id : String, @thread_ts : String, @title : String)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      FieldChecks.blank_issue(issues, "assistant_threads_set_title", "channel_id", @channel_id, "Channel ID")
      FieldChecks.timestamp_issue(issues, "assistant_threads_set_title", "thread_ts", @thread_ts, "Thread timestamp")
      FieldChecks.blank_issue(issues, "assistant_threads_set_title", "title", @title, "Title")
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "channel_id", @channel_id
        json.field "thread_ts", @thread_ts
        json.field "title", @title
      end
    end

    def method_path : String
      "assistant.threads.setTitle"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end
  end
end
