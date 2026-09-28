class Slack::App
  @error_handler : ErrorHandler? = nil

  # Sets the handler for exceptions that listeners and their middleware raise,
  # the way Bolt's `app.error` does. Without a handler, the app logs
  # `ListenerError#message`. The handler runs in the listener's fiber, after the
  # request has its response: an exception before `ack` has already given a
  # failed outcome (HTTP 500). An exception in the handler is logged by class.
  #
  # ```
  # app.error do |error, ctx|
  #   ctx.log.error { "#{error.payload_kind}: #{error.cause.class}" }
  # end
  # ```
  def error(&handler : ListenerError, Context ->) : Nil
    @error_handler = handler
  end

  private def report(error : ListenerError, context : Context) : Nil
    if handler = @error_handler
      handler.call(error, context)
    else
      @log.error { error.message }
    end
  rescue exception
    @log.error { "Error handler raised #{exception.class} for #{error.route}" }
  end
end
