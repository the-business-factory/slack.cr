require "json"

module Slack::Api
  # Sets the lifecycle status of an agent session. Slack creates the session if necessary.
  # See https://docs.slack.dev/reference/methods/agents.sessions.setStatus.
  #
  # Slack requires *channel_id* for public channels and *thread_ts* for
  # thread sessions in regular channels and DMs; it checks both remotely.
  # *title* (up to 200 characters) and *initiator_user_id* apply only when Slack
  # creates the session. *icon* and *username* (up to 200 characters) need the
  # `chat:write.customize` scope.
  #
  # ```
  # session = client.call(Slack::Api::AgentsSessionsSetStatus.new(
  #   status: Slack::Api::Streaming::SessionStatus::Processing,
  #   channel_id: "C123", thread_ts: "1234567890.123456", title: "Scuba diving research"))
  # session.agent_status # => "processing"
  # ```
  struct AgentsSessionsSetStatus < Request(Models::Agents::Session)
    include JsonBody
    include UI::ValueValidation

    MAX_TITLE_SIZE    = 200
    MAX_USERNAME_SIZE = 200

    getter status : Streaming::SessionStatus
    getter channel_id : String?
    getter thread_ts : String?
    getter title : String?
    getter initiator_user_id : String?
    getter icon : UI::Icon?
    getter username : String?

    def initialize(*, @status : Streaming::SessionStatus, @channel_id : String? = nil, @thread_ts : String? = nil,
                   @title : String? = nil, @initiator_user_id : String? = nil,
                   @icon : UI::Icon? = nil, @username : String? = nil)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if (thread_ts = @thread_ts) && !Streaming.timestamp?(thread_ts)
        issues << UI::ValidationIssue.new("agents_sessions_set_status.thread_ts.invalid", "thread_ts",
          "Thread timestamp must contain digits, a decimal point, and fractional digits.")
      end
      length_issue(issues, @title, MAX_TITLE_SIZE, "agents_sessions_set_status.title.too_long", "title")
      length_issue(issues, @username, MAX_USERNAME_SIZE, "agents_sessions_set_status.username.too_long", "username")
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "status", @status.wire_value
        json.field "channel_id", @channel_id if @channel_id
        json.field "thread_ts", @thread_ts if @thread_ts
        json.field "title", @title if @title
        json.field "initiator_user_id", @initiator_user_id if @initiator_user_id
        if icon = @icon
          json.field icon.wire_field, icon.value
        end
        json.field "username", @username if @username
      end
    end

    def method_path : String
      "agents.sessions.setStatus"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
