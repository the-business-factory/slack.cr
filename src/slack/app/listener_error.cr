# Wraps an exception that a listener or its middleware raised. `App#error`
# handlers receive it. `#cause` is the original exception.
#
# The message holds only the context type, the exception class, and whether
# the request already had a response. It never holds the payload or the
# original message, because they can contain user data.
class Slack::App::ListenerError < Exception
  # What the request carried, for example `"event app_mention"`,
  # `"command /deploy"`, or `"block_actions"`.
  getter payload_kind : String
  # The context type of the listener, for example `"Slack::App::CommandContext"`.
  getter route : String
  # True when the request already had its response before the exception.
  getter? acknowledged : Bool

  def initialize(cause : Exception, @payload_kind : String, @route : String, @acknowledged : Bool)
    moment = @acknowledged ? "after" : "before"
    super("Listener for #{@route} raised #{cause.class} #{moment} acknowledging", cause)
  end
end
