# Keeps the thread context in the metadata of the app's first reply in the
# thread, like the default store of Bolt. It needs no storage of its own.
#
# `#get` reads the first four messages of the thread with
# `conversations.replies` and returns the context from the first message of
# the bot user without a subtype. `#save` replaces the metadata of that message
# with `chat.update`, and sends its text and blocks again unchanged. When the
# app has not replied yet, or the event has no bot authorization, `#get`
# returns nil and `#save` does nothing.
#
# Scopes: `im:history` for `conversations.replies` and `chat:write` for
# `chat.update`. Each call is one Web API request; the store keeps no cache.
class Slack::App::Assistant::MetadataThreadContextStore < Slack::App::Assistant::ThreadContextStore
  # The metadata `event_type` of a saved thread context.
  EVENT_TYPE = "assistant_thread_context"

  # Bolt reads the same number of messages: the thread root, the user's first
  # message, and the first replies.
  MESSAGES_READ = 4

  # The message metadata that holds *context*.
  def self.metadata(context : Slack::EventData::AssistantThreadContext) : Slack::UI::MessageMetadata
    Slack::UI::MessageMetadata.new(EVENT_TYPE, JSON.parse(context.to_json))
  end

  def get(*, client : Slack::Api::Client, channel_id : String, thread_ts : String,
          bot_user_id : String?) : Slack::EventData::AssistantThreadContext?
    reply = first_reply(client, channel_id, thread_ts, bot_user_id) || return
    metadata = reply.metadata || return
    return unless metadata["event_type"]?.try(&.as_s?) == EVENT_TYPE
    payload = metadata["event_payload"]?.try(&.as_h?) || return
    Slack::EventData::AssistantThreadContext.from_json(payload.to_json)
  rescue JSON::ParseException
    # Metadata of another shape is not a saved context.
    nil
  end

  def save(*, client : Slack::Api::Client, channel_id : String, thread_ts : String, bot_user_id : String?,
           context : Slack::EventData::AssistantThreadContext) : Nil
    reply = first_reply(client, channel_id, thread_ts, bot_user_id) || return
    # The received blocks are sent back as they are; `Api::ChatUpdate` takes
    # only blocks that the library builds, and text alone would remove them.
    client.call("chat.update", {
      channel:  channel_id,
      ts:       reply.ts,
      text:     reply.text,
      blocks:   reply.blocks_json,
      metadata: self.class.metadata(context),
    }, Slack::Api::RateLimitTier::Tier3)
    nil
  end

  private def first_reply(client : Slack::Api::Client, channel_id : String, thread_ts : String,
                          bot_user_id : String?) : Slack::Models::Message?
    return unless bot_user_id
    request = Slack::Api::ConversationsReplies.new(channel_id, thread_ts, include_all_metadata: true,
      oldest: thread_ts, limit: MESSAGES_READ)
    client.call(request).messages.find { |message| message.subtype.nil? && message.user == bot_user_id }
  end
end
