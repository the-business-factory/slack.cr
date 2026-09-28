# The assistant thread in an `assistant_thread_started` or
# `assistant_thread_context_changed` event. Reply in `channel_id` with
# `thread_ts`.
struct Slack::EventData::AssistantThread
  include JSON::Serializable

  # The user who opened the thread.
  getter user_id : String

  # The direct message channel of the thread.
  getter channel_id : String
  getter thread_ts : String

  # What the user views in Slack. Nil when Slack does not send it.
  getter context : AssistantThreadContext?
end
