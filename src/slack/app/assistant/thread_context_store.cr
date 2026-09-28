# Keeps the thread context of app threads: the channel that the user views
# while the thread is open. `Assistant` reads it for user messages, because
# their events do not include it.
#
# `MetadataThreadContextStore` is the default. Subclass this type to keep the
# context somewhere else, for example in a database. *client* is the Web API
# client of the request. *bot_user_id* is the app's bot user from the event's
# `authorizations`, or nil when the event has no bot authorization.
abstract class Slack::App::Assistant::ThreadContextStore
  # Returns the saved context of the thread, or nil when there is none.
  abstract def get(*, client : Slack::Api::Client, channel_id : String, thread_ts : String,
                   bot_user_id : String?) : Slack::EventData::AssistantThreadContext?

  # Saves *context* for the thread.
  abstract def save(*, client : Slack::Api::Client, channel_id : String, thread_ts : String, bot_user_id : String?,
                    context : Slack::EventData::AssistantThreadContext) : Nil
end
