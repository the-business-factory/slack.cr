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
  def initialize(*, @authorizer : Authorizer, @log : ::Log = ::Log.for("slack.app"),
                 @ack_timeout : Time::Span = DEFAULT_ACK_TIMEOUT,
                 @workflow_client : WorkflowClient = ->(token : Slack::Auth::Secret) { Slack::Api::Client.new(token: token) })
    raise ArgumentError.new("ack_timeout must be positive") unless @ack_timeout.positive?
  end

  # Adds global middleware. It runs, in registration order, before the
  # middleware and handler of every matched listener.
  def use(&middleware : Context, Proc(Nil) ->) : Nil
    @middleware << middleware
  end

  # Listens for Events API events of *type*, for example `"app_mention"`.
  def event(type : String, *, middleware : Array(Middleware) = [] of Middleware,
            &handler : EventContext ->) : Nil
    @router.event(type, middleware, handler)
  end

  # Listens for `message` events without a subtype. A string *pattern* matches
  # text that contains it, a regex matches the text, and nil matches every message.
  def message(pattern : (String | Regex)? = nil, *, middleware : Array(Middleware) = [] of Middleware,
              &handler : MessageContext ->) : Nil
    @router.message(pattern, middleware, handler)
  end

  # Listens for `function_executed` events of the custom function *callback_id*.
  def function(callback_id : String, *, middleware : Array(Middleware) = [] of Middleware,
               &handler : FunctionContext ->) : Nil
    @router.function(callback_id, middleware, handler)
  end

  # Listens for `block_actions` whose action has *action_id* and, when given, *block_id*.
  def action(action_id : String | Regex, block_id : String? = nil, *,
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
  def options(action_id : String | Regex, *, middleware : Array(Middleware) = [] of Middleware,
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
    client = authorize(payload) || return Outcome.unauthorized
    environment = Environment.new(client, @log, delivery, @workflow_client)
    listener = find_listener(payload, environment) || return Outcome.acknowledged
    spawn(name: "slack.app.listener") { run(listener, environment.ack) }
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

  # Exceptions are logged by class only: their messages can hold payload data.
  private def run(listener : Listener, ack : Ack) : Nil
    listener.call(@middleware)
    ack.complete(Outcome.acknowledged)
  rescue error
    moment = ack.complete(Outcome.failed) ? "before" : "after"
    @log.error { "Listener for #{listener.context.class} raised #{error.class} #{moment} acknowledging" }
  end

  private def wait(ack : Ack) : Outcome
    ack.wait(@ack_timeout) || begin
      @log.warn { "No acknowledgment within #{@ack_timeout.total_milliseconds.to_i} ms; sent an empty acknowledgment" }
      Outcome.acknowledged
    end
  end

  private def describe(payload : Payload) : String
    case payload
    in Slack::VerifiedEvent then "event #{payload.event.type}"
    in Slack::Command       then "command #{payload.command}"
    in Slack::Interaction   then payload.type
    end
  end
end
