require "json"

module Slack::Api
  # Shows a status, such as "is thinking...", in an app thread.
  # See https://docs.slack.dev/reference/methods/assistant.threads.setStatus.
  #
  # Slack removes the status after two minutes if the app sends no message.
  # An empty *status* clears it. *loading_messages* (1 to 10) rotate in the
  # loading indicator. *icon* and *username* need the `chat:write.customize` scope.
  # Slack names `agents.sessions.setStatus` (`AgentsSessionsSetStatus`) as the
  # successor of this method.
  #
  # ```
  # client.call(Slack::Api::AssistantThreadsSetStatus.new(channel_id: "D123",
  #   thread_ts: "1724264405.531769", status: "is thinking...",
  #   loading_messages: ["Reading the thread", "Checking the report"]))
  # ```
  struct AssistantThreadsSetStatus < Request(Models::DefaultResponse)
    include JsonBody

    MAX_LOADING_MESSAGES = 10

    getter channel_id : String
    getter thread_ts : String
    getter status : String
    getter icon : UI::Icon?
    getter username : String?
    @loading_messages : Array(String)?

    # Copies *loading_messages*, so later changes to the argument have no effect.
    def initialize(*, @channel_id : String, @thread_ts : String, @status : String,
                   loading_messages : Enumerable(String)? = nil, @icon : UI::Icon? = nil, @username : String? = nil)
      @loading_messages = loading_messages.try(&.map(&.itself))
    end

    # A copy of the loading messages.
    def loading_messages : Array(String)?
      @loading_messages.try(&.dup)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      FieldChecks.blank_issue(issues, "assistant_threads_set_status", "channel_id", @channel_id, "Channel ID")
      FieldChecks.timestamp_issue(issues, "assistant_threads_set_status", "thread_ts", @thread_ts, "Thread timestamp")
      loading_message_issue(issues)
      FieldChecks.blank_issue(issues, "assistant_threads_set_status", "username", @username, "Username")
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "channel_id", @channel_id
        json.field "thread_ts", @thread_ts
        json.field "status", @status
        json.field "loading_messages", @loading_messages if @loading_messages
        if icon = @icon
          json.field icon.wire_field, icon.value
        end
        json.field "username", @username if @username
      end
    end

    def method_path : String
      "assistant.threads.setStatus"
    end

    # Slack gives this method its own limit of 600 calls a minute for each app
    # and workspace. The client paces special methods at a lower rate.
    def tier : RateLimitTier
      RateLimitTier::Special
    end

    private def loading_message_issue(issues : Array(UI::ValidationIssue)) : Nil
      return unless messages = @loading_messages
      if messages.empty?
        issues << issue("loading_messages.empty", "loading_messages",
          "Loading messages must contain at least one message. Use nil to omit them.")
      elsif messages.size > MAX_LOADING_MESSAGES
        issues << issue("loading_messages.too_many", "loading_messages",
          "Loading messages cannot contain more than #{MAX_LOADING_MESSAGES} messages.")
      end
    end

    private def issue(code : String, path : String, message : String) : UI::ValidationIssue
      UI::ValidationIssue.new("assistant_threads_set_status.#{code}", path, message)
    end
  end
end
