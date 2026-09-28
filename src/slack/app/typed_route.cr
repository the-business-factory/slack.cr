# :nodoc:
class Slack::App::TypedRoute(C) < Slack::App::Route
  # *acknowledge_first* sends the empty acknowledgment before the handler runs.
  def initialize(@middleware : Array(Middleware), @handler : Proc(C, Nil), @acknowledge_first : Bool,
                 &@match : App::Payload, Environment -> C?)
  end

  def listener(payload : App::Payload, environment : Environment) : Listener?
    context = @match.call(payload, environment) || return
    handler = @handler
    if @acknowledge_first
      Listener.new(context, @middleware, -> {
        environment.ack.respond(Outcome.acknowledged)
        handler.call(context)
      })
    else
      Listener.new(context, @middleware, -> { handler.call(context) })
    end
  end
end
