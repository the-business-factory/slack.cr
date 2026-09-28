# A step that runs before a listener. It receives the listener's context and a
# proc that runs the rest of the chain. A step that does not call it stops the
# chain; the request then gets an empty acknowledgment.
#
# ```
# app.use do |ctx, call_next|
#   ctx.store["started"] = Time.utc.to_rfc3339
#   call_next.call
# end
# ```
alias Slack::App::Middleware = Proc(Slack::App::Context, Proc(Nil), Nil)
