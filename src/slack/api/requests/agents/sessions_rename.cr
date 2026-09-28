require "json"

module Slack::Api
  # Renames an agent session. For a session channel, Slack also renames the channel.
  # See https://docs.slack.dev/reference/methods/agents.sessions.rename.
  #
  # Slack requires *channel_id* for public channels and *thread_ts* for thread
  # sessions in regular channels and DMs. Omit *thread_ts* for a session channel.
  #
  # ```
  # session = client.call(Slack::Api::AgentsSessionsRename.new(title: "Bora Bora trip prep",
  #   channel_id: "C123", thread_ts: "1234567890.123456"))
  # session.title # => "Bora Bora trip prep"
  # ```
  struct AgentsSessionsRename < Request(Models::Agents::SessionTitle)
    include JsonBody
    include UI::ValueValidation

    MAX_TITLE_SIZE = 200

    getter title : String
    getter channel_id : String?
    getter thread_ts : String?

    def initialize(*, @title : String, @channel_id : String? = nil, @thread_ts : String? = nil)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @title.blank?
        issues << UI::ValidationIssue.new("agents_sessions_rename.title.blank", "title", "Title must not be blank.")
      end
      length_issue(issues, @title, MAX_TITLE_SIZE, "agents_sessions_rename.title.too_long", "title")
      if (thread_ts = @thread_ts) && !Streaming.timestamp?(thread_ts)
        issues << UI::ValidationIssue.new("agents_sessions_rename.thread_ts.invalid", "thread_ts",
          "Thread timestamp must contain digits, a decimal point, and fractional digits.")
      end
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "title", @title
        json.field "channel_id", @channel_id if @channel_id
        json.field "thread_ts", @thread_ts if @thread_ts
      end
    end

    def method_path : String
      "agents.sessions.rename"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
