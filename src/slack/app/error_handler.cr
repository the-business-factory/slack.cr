# Receives each exception that a listener or its middleware raises. See `App#error`.
alias Slack::App::ErrorHandler = Proc(Slack::App::ListenerError, Slack::App::Context, Nil)
