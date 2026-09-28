# The context of an `Assistant` handler. *E* is the event type:
# `Events::AssistantThreadStarted`, `Events::AssistantThreadContextChanged`, or
# `Events::Message`. The app acknowledges the event before the handler runs.
#
# Every utility sends one Web API request (or a few, see `#thread_context`)
# through `#client` to the thread `#channel_id` and `#thread_ts`, and raises
# the errors of `Api::Client#call`.
struct Slack::App::AssistantContext(E) < Slack::App::Context
  getter envelope : Slack::VerifiedEvent
  getter event : E
  # The app's direct message channel with the user.
  getter channel_id : String
  getter thread_ts : String
  # The user of the thread. Nil when a message event has no user.
  getter user_id : String?

  def initialize(environment : Environment, @envelope : Slack::VerifiedEvent, @event : E,
                 @store : Assistant::ThreadContextStore, *, @channel_id : String, @thread_ts : String,
                 @user_id : String?, @event_context : Slack::EventData::AssistantThreadContext?)
    super(environment)
  end

  # Posts *text* in the thread with `chat.postMessage`. The message carries
  # the thread context as metadata when there is one, like Bolt's `say`.
  def say(text : String) : Slack::Models::Chat::PostMessage
    client.call(Slack::Api::ChatPostMessage.new(channel: @channel_id, text: text, thread_ts: @thread_ts,
      metadata: context_metadata))
  end

  # Posts the Block Kit *message* in the thread. See the text overload.
  def say(message : Slack::UI::Message) : Slack::Models::Chat::PostMessage
    client.call(Slack::Api::ChatPostMessage.new(channel: @channel_id, message: message, thread_ts: @thread_ts,
      metadata: context_metadata))
  end

  # Shows *status*, such as "is thinking...", with `assistant.threads.setStatus`.
  # An empty *status* clears it. See `Api::AssistantThreadsSetStatus`.
  def set_status(status : String, loading_messages : Enumerable(String)? = nil) : Nil
    client.call(Slack::Api::AssistantThreadsSetStatus.new(channel_id: @channel_id, thread_ts: @thread_ts,
      status: status, loading_messages: loading_messages))
    nil
  end

  # Shows up to four *prompts* with `assistant.threads.setSuggestedPrompts`.
  #
  # The request has no `thread_ts`: Slack then sets the prompts for the latest
  # message of the channel, and a call with `thread_ts` fails silently for
  # agent apps.
  def set_suggested_prompts(prompts : Enumerable(Slack::Api::SuggestedPrompt), title : String? = nil) : Nil
    client.call(Slack::Api::AssistantThreadsSetSuggestedPrompts.new(channel_id: @channel_id, prompts: prompts,
      title: title))
    nil
  end

  # Sets the thread title with `assistant.threads.setTitle`. The name follows
  # the Slack method and Bolt, and the method sends a request.
  # ameba:disable Naming/AccessorMethodName
  def set_title(title : String) : Nil
    client.call(Slack::Api::AssistantThreadsSetTitle.new(channel_id: @channel_id, thread_ts: @thread_ts, title: title))
    nil
  end

  # The channel that the user views. Thread events give it with a channel ID;
  # otherwise, the context store reads it. Nil when neither has one.
  def thread_context : Slack::EventData::AssistantThreadContext?
    event_context = @event_context
    return event_context if event_context && event_context.channel_id
    @store.get(client: client, channel_id: @channel_id, thread_ts: @thread_ts, bot_user_id: bot_user_id)
  end

  # Saves *context* in the context store. The default is the context of the
  # thread event. Does nothing when there is no context, as for a user message.
  def save_thread_context(context : Slack::EventData::AssistantThreadContext? = @event_context) : Nil
    return unless context
    @store.save(client: client, channel_id: @channel_id, thread_ts: @thread_ts, bot_user_id: bot_user_id,
      context: context)
  end

  # Starts a streamed reply in the thread, yields its `Api::MessageStream`, and
  # stops it with *session_status* and the thread context as metadata. Returns
  # the stopped message.
  #
  # The helper reads the thread context before it starts the stream, so a
  # failed read raises before Slack opens a stream. The stream starts and stops
  # without content, so the block chooses the content mode with its first
  # `append`. When the block raises, the stream is not stopped.
  #
  # ```
  # ctx.stream do |stream|
  #   stream.append(ctx.client, markdown_text: "Revenue grew 4%.")
  # end
  # ```
  def stream(*, task_display_mode : Slack::Api::Streaming::TaskDisplayMode? = nil,
             session_status : Slack::Api::Streaming::SessionStatus = Slack::Api::Streaming::SessionStatus::Closed,
             & : Slack::Api::MessageStream ->) : Slack::Models::Chat::StreamMessage
    user_id = @user_id
    team_id = @envelope.team_id
    # Slack needs both recipient fields or neither.
    recipient_user_id, recipient_team_id = user_id && team_id ? {user_id, team_id} : {nil, nil}
    # Read the context first: a failed read then leaves no open stream behind.
    metadata = context_metadata
    message_stream = client.start_stream(Slack::Api::ChatStartStream.new(channel: @channel_id, thread_ts: @thread_ts,
      recipient_user_id: recipient_user_id, recipient_team_id: recipient_team_id, task_display_mode: task_display_mode))
    yield message_stream
    message_stream.stop(client, session_status: session_status, metadata: metadata)
  end

  private def context_metadata : Slack::UI::MessageMetadata?
    thread_context.try { |context| Assistant::MetadataThreadContextStore.metadata(context) }
  end

  private def bot_user_id : String?
    @envelope.authorizations.find(&.bot?).try(&.user_id)
  end
end
