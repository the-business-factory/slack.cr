# A user clicked the stop button of an agent session in the `processing`
# status. Stop the work for `channel` and `thread_ts`, then change the session
# status yourself: Slack does not change it.
# https://docs.slack.dev/reference/events/agent_session_stopped
struct Slack::Events::AgentSessionStopped < Slack::Event
  getter channel : String
  getter user : String
  getter thread_ts : String
  getter event_ts : String

  # The app's streaming messages that Slack stopped. Empty when no stream was
  # active.
  getter streaming_message_ts : Array(String)
end
