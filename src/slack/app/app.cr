require "log"

# Routes verified Slack requests to listeners, the way Bolt's `App` does.
#
# ```
# client = Slack::Api::Client.new(token: Slack::Auth::Secret.new(ENV["SLACK_BOT_TOKEN"]))
# app = Slack::App.new(authorizer: Slack::App::SingleTokenAuthorizer.new(client))
#
# app.command("/deploy") do |ctx|
#   ctx.ack(Slack::Commands::Response.new(text: "Deploy started."))
# end
#
# verifier = Slack::Webhooks::Verifier.new(Slack::Auth::Secret.new(ENV["SLACK_SIGNING_SECRET"]))
# HTTP::Server.new([Slack::App::HttpReceiver.new(app, verifier)]).listen(3000)
# ```
#
# Register listeners and middleware before the app receives requests. For each
# request, the first listener that matches, in registration order, runs.
#
# Listener lifecycle: `#dispatch` runs the middleware chain and the listener in
# a new fiber and waits until the listener acknowledges, the listener returns,
# or *ack_timeout* passes. It then returns the `Outcome`. The listener fiber
# continues after that and ends when the listener returns; the app does not
# cancel it. A listener that returns without `ack` gets an empty
# acknowledgment. Event, message, and function listeners are acknowledged
# before they run.
class Slack::App
  alias Payload = Slack::VerifiedEvent | Slack::Command | Slack::Interaction

  # Builds the Web API client for a custom step's workflow token.
  alias WorkflowClient = Proc(Slack::Auth::Secret, Slack::Api::Client)

  # Slack expects an acknowledgment within three seconds. The margin leaves
  # time to write the response.
  DEFAULT_ACK_TIMEOUT = 2500.milliseconds

  getter log : ::Log
  getter ack_timeout : Time::Span

  @router = Router.new
  @middleware = [] of Middleware

  # *workflow_client* builds the client for a custom step's workflow token
  # (`bot_access_token`). Give one to set the API configuration or transport.
  # *response_url_transport* sends `respond` posts. They go to Slack's
  # `response_url` hosts, not the Web API, so they do not use the client.
  def initialize(*, @authorizer : Authorizer, @log : ::Log = ::Log.for("slack.app"),
                 @ack_timeout : Time::Span = DEFAULT_ACK_TIMEOUT,
                 @workflow_client : WorkflowClient = ->(token : Slack::Auth::Secret) { Slack::Api::Client.new(token: token) },
                 @response_url_transport : Slack::Auth::Transport = Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new))
    raise ArgumentError.new("ack_timeout must be positive") unless @ack_timeout.positive?
  end

  # Adds global middleware. It runs, in registration order, before the
  # middleware and handler of every matched listener.
  def use(&middleware : Context, Proc(Nil) ->) : Nil
    @middleware << middleware
  end

  # Listens for Events API events that are an *event_type*, and gives the
  # listener the event as that type. *event_type* is a `Slack::Event` type, such
  # as `Slack::Events::AppMentioned`, or a type that event types include, such
  # as `Slack::Events::MessageSubtype`. `Slack::Event` matches every event.
  #
  # ```
  # app.event(Slack::Events::ReactionAdded) do |ctx|
  #   ctx.log.info { "Reaction: #{ctx.event.reaction}" }
  # end
  # ```
  #
  # Most types in `Slack::Event::KNOWN_TYPES` also have an `on_*` method, for
  # example `#on_app_mention`. For `message` events, use `#message`. See the
  # `on_*` exclusions below.
  def event(event_type : T.class, *, middleware : Array(Middleware) = [] of Middleware,
            &handler : EventContext(T) ->) : Nil forall T
    {% unless T <= ::Slack::Event || ::Slack::Event.all_subclasses.any? { |event| event <= T } %}
      {% raise "App#event takes a Slack::Event type, not #{T}" %}
    {% end %}
    @router.event(event_type, middleware, handler)
  end

  # Listens for events of *type* that this library does not map, for example a
  # new Slack event. The event is a `Slack::Events::Unknown`, with its data in `raw`.
  #
  # ```
  # app.event(Slack::Events::Unknown, type: "future_type") do |ctx|
  #   ctx.log.info { ctx.event.type }
  # end
  # ```
  def event(event_type : Slack::Events::Unknown.class, *, type : String,
            middleware : Array(Middleware) = [] of Middleware,
            &handler : EventContext(Slack::Events::Unknown) ->) : Nil
    @router.unknown_event(type, middleware, handler)
  end

  # Listens for `message` events without a subtype. A string *pattern* matches
  # text that contains it, a regex matches the text, and nil matches every message.
  # To match messages with a subtype, give the subtype to `#event`, for example
  # `Slack::Events::Message::ChannelTopic`.
  def message(pattern : (String | Regex)? = nil, *, middleware : Array(Middleware) = [] of Middleware,
              &handler : EventContext(Slack::Events::Message) ->) : Nil
    @router.message(pattern, middleware, handler)
  end

  # Some types have no `on_*` method, because a dedicated listener gives them
  # behavior that `EventContext` does not have:
  # - `message`: `#message` is the listener for plain messages and also
  #   matches text.
  # - `function_executed`: `#function` gives the workflow token client and
  #   `complete` and `fail`.
  # - `assistant_thread_started` and `assistant_thread_context_changed`:
  #   `#assistant` saves the thread context and says in the thread.
  #
  # `event(T)` with these types still gives an ordinary event listener.
  {% for type_name, event_type in Slack::Event::KNOWN_TYPES %}
    {% unless %w[message function_executed assistant_thread_started assistant_thread_context_changed].includes?(type_name) %}
      # Listens for `{{ type_name.id }}` events. Same as `event({{ event_type }})`.
      def on_{{ type_name.id }}(*, middleware : Array(Middleware) = [] of Middleware,
                                &handler : EventContext({{ event_type }}) ->) : Nil
        event({{ event_type }}, middleware: middleware, &handler)
      end
    {% end %}
  {% end %}

  # Listens for `function_executed` events of the custom function *callback_id*.
  def function(callback_id : String, *, middleware : Array(Middleware) = [] of Middleware,
               &handler : FunctionContext ->) : Nil
    @router.function(callback_id, middleware, handler)
  end

  # Listens for `block_actions` whose action has *action_id* and, when given, *block_id*.
  # Give a `Slack::UI::ActionId` to use the same constant as the element.
  def action(action_id : String | Regex | Slack::UI::ActionId, block_id : String? = nil, *,
             middleware : Array(Middleware) = [] of Middleware, &handler : ActionContext ->) : Nil
    @router.action(action_id, block_id, middleware, handler)
  end

  # Listens for the slash command *name*, for example `"/deploy"`.
  def command(name : String, *, middleware : Array(Middleware) = [] of Middleware,
              &handler : CommandContext ->) : Nil
    @router.command(name, middleware, handler)
  end

  # Listens for global and message shortcuts with *callback_id*.
  def shortcut(callback_id : String | Regex, *, middleware : Array(Middleware) = [] of Middleware,
               &handler : ShortcutContext ->) : Nil
    @router.shortcut(callback_id, middleware, handler)
  end

  # Listens for `block_suggestion` requests from the external select *action_id*.
  # Give a `Slack::UI::ActionId` to use the same constant as the element.
  def options(action_id : String | Regex | Slack::UI::ActionId, *, middleware : Array(Middleware) = [] of Middleware,
              &handler : OptionsContext ->) : Nil
    @router.options(action_id, middleware, handler)
  end

  # Listens for `view_submission` payloads of views with *callback_id*.
  def view(callback_id : String | Regex, *, middleware : Array(Middleware) = [] of Middleware,
           &handler : ViewContext ->) : Nil
    @router.view(callback_id, middleware, handler)
  end

  # Listens for `view_closed` payloads of views with *callback_id*.
  def view_closed(callback_id : String | Regex, *, middleware : Array(Middleware) = [] of Middleware,
                  &handler : ViewClosedContext ->) : Nil
    @router.view_closed(callback_id, middleware, handler)
  end

  # Authorizes and routes one verified payload and waits for its acknowledgment.
  # Pass only payloads decoded from verified bytes. *delivery* holds the Events
  # API retry headers, if any.
  def dispatch(payload : Payload, delivery : Slack::Events::Delivery? = nil) : Outcome
    if outcome = apply_lifecycle(payload, delivery)
      return outcome
    end
    client = authorize(payload) || return Outcome.unauthorized
    environment = Environment.new(client, @log, delivery, @workflow_client, @response_url_transport, payload, @authorizer)
    listener = find_listener(payload, environment) || return Outcome.acknowledged
    payload_kind = describe(payload)
    spawn(name: "slack.app.listener") { run(listener, environment.ack, payload_kind) }
    wait(environment.ack)
  rescue error
    @log.error { "Routing #{describe(payload)} raised #{error.class}" }
    Outcome.failed
  end

  private def authorize(payload : Payload) : Slack::Api::Client?
    @authorizer.authorize(payload)
  rescue error
    @log.warn { "Authorization of #{describe(payload)} failed: #{error.class}" }
    nil
  end

  private def find_listener(payload : Payload, environment : Environment) : Listener?
    listener = @router.listener(payload, environment)
    @log.info { "No listener matched #{describe(payload)}" } unless listener
    listener
  end

  # Exceptions go to the error handler, or are logged by class only: their
  # messages can hold payload data.
  private def run(listener : Listener, ack : Ack, payload_kind : String) : Nil
    listener.call(@middleware)
    ack.complete(Outcome.acknowledged)
  rescue error
    # Yields to the receiver first, so the failed response does not wait for the handler.
    acknowledged = !ack.respond(Outcome.failed)
    report(ListenerError.new(error, payload_kind, listener.context.class.name, acknowledged), listener.context)
  end

  private def wait(ack : Ack) : Outcome
    ack.wait(@ack_timeout) || begin
      @log.warn { "No acknowledgment within #{@ack_timeout.total_milliseconds.to_i} ms; sent an empty acknowledgment" }
      Outcome.acknowledged
    end
  end

  private def describe(payload : Payload) : String
    App.describe(payload)
  end

  # :nodoc:
  # Names *payload* in logs and errors without payload data, for example
  # `"command /deploy"`.
  def self.describe(payload : Payload) : String
    case payload
    in Slack::VerifiedEvent then "event #{payload.event.type}"
    in Slack::Command       then "command #{payload.command}"
    in Slack::Interaction   then payload.type
    end
  end
end
