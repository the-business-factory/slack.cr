# :nodoc:
# A matched route: the typed context, the route's middleware, and the handler.
struct Slack::App::Listener
  getter context : Context

  def initialize(@context : Context, @middleware : Array(Middleware), @handler : Proc(Nil))
  end

  # Runs *global* middleware, then this listener's middleware, then the handler.
  def call(global : Array(Middleware)) : Nil
    run(global + @middleware, 0)
  end

  private def run(chain : Array(Middleware), index : Int32) : Nil
    if step = chain[index]?
      step.call(@context, -> { run(chain, index + 1) })
    else
      @handler.call
    end
  end
end
