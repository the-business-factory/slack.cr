# Handles the events of app threads, the way Bolt's `Assistant` class does.
# Register the handlers, then add the assistant to an app with `App#assistant`.
#
# ```
# assistant = Slack::App::Assistant.new
#
# assistant.thread_started do |ctx|
#   ctx.say("How can I help?")
#   ctx.set_suggested_prompts([Slack::Api::SuggestedPrompt.new("Summarize", "Summarize this channel.")])
# end
#
# assistant.user_message do |ctx|
#   ctx.set_status("is thinking...")
#   ctx.stream { |stream| stream.append(ctx.client, markdown_text: "Here is the summary.") }
# end
#
# app.assistant(assistant)
# ```
#
# The assistant handles:
#
# - `assistant_thread_started` with the `#thread_started` handler.
# - `assistant_thread_context_changed` with the `#thread_context_changed`
#   handler. Without one, it saves the new context in the context store.
# - User messages in the app's direct messages with the `#user_message`
#   handler: `message` events with `channel_type` `im` and a `thread_ts`,
#   without a subtype, and without a `bot_id`.
#
# Events without a handler go to the other listeners of the app.
class Slack::App::Assistant
  getter context_store : ThreadContextStore

  @thread_started : Proc(AssistantContext(Slack::Events::AssistantThreadStarted), Nil)? = nil
  @thread_context_changed : Proc(AssistantContext(Slack::Events::AssistantThreadContextChanged), Nil)? = nil
  @user_message : Proc(AssistantContext(Slack::Events::Message), Nil)? = nil

  # *context_store* keeps the channel that the user views for each thread.
  def initialize(*, @context_store : ThreadContextStore = MetadataThreadContextStore.new)
  end

  # Handles a new app thread. Use it to greet the user and set suggested prompts.
  def thread_started(&handler : AssistantContext(Slack::Events::AssistantThreadStarted) ->) : Nil
    @thread_started = handler
  end

  # Handles a change of the channel that the user views while the thread is open.
  # A handler replaces the default, so call `AssistantContext#save_thread_context`
  # to keep the new context.
  def thread_context_changed(&handler : AssistantContext(Slack::Events::AssistantThreadContextChanged) ->) : Nil
    @thread_context_changed = handler
  end

  # Handles a message that the user sends in an app thread.
  def user_message(&handler : AssistantContext(Slack::Events::Message) ->) : Nil
    @user_message = handler
  end

  # :nodoc:
  # The routes for the handlers that are registered now.
  def routes(middleware : Array(Middleware)) : Array(Route)
    routes = [] of Route
    if handler = @thread_started
      routes << thread_route(Slack::Events::AssistantThreadStarted, middleware, handler)
    end
    routes << thread_route(Slack::Events::AssistantThreadContextChanged, middleware,
      @thread_context_changed || ->(ctx : AssistantContext(Slack::Events::AssistantThreadContextChanged)) {
        ctx.save_thread_context
      })
    if handler = @user_message
      routes << user_message_route(middleware, handler)
    end
    routes
  end

  private def thread_route(type : E.class, middleware : Array(Middleware),
                           handler : Proc(AssistantContext(E), Nil)) : Route forall E
    store = @context_store
    TypedRoute(AssistantContext(E)).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      event = payload.event
      next unless event.is_a?(E)
      thread = event.assistant_thread
      AssistantContext(E).new(environment, payload, event, store, channel_id: thread.channel_id,
        thread_ts: thread.thread_ts, user_id: thread.user_id, event_context: thread.context)
    end
  end

  private def user_message_route(middleware : Array(Middleware),
                                 handler : Proc(AssistantContext(Slack::Events::Message), Nil)) : Route
    store = @context_store
    TypedRoute(AssistantContext(Slack::Events::Message)).new(middleware, handler, acknowledge_first: true) do |payload, environment|
      next unless payload.is_a?(Slack::VerifiedEvent)
      message = payload.event
      next unless message.is_a?(Slack::Events::Message) && message.im? && message.subtype.nil? && message.bot_id.nil?
      channel = message.channel
      thread_ts = message.thread_ts
      if channel && thread_ts
        AssistantContext(Slack::Events::Message).new(environment, payload, message, store, channel_id: channel,
          thread_ts: thread_ts, user_id: message.user, event_context: nil)
      end
    end
  end
end
