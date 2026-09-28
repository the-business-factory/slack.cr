# A user changed the title of an agent session.
# https://docs.slack.dev/reference/events/agent_session_title_changed
struct Slack::Events::AgentSessionTitleChanged < Slack::Event
  getter channel : String
  getter user : String
  getter thread_ts : String
  getter event_ts : String
  getter title : String

  # Nil when the session had no title before the change.
  getter previous_title : String?

  # Slack sends it for an organization-level installation.
  getter enterprise_id : String?
end
