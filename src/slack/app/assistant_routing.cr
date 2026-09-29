class Slack::App
  # Adds the handlers of *assistant*. Register its handlers first: the app
  # adds the handlers that exist now. *middleware* runs before each handler.
  #
  # The first listener that matches runs, so add the assistant before a
  # `message` or `event` listener that would match the same messages.
  def assistant(assistant : Assistant, *, middleware : Array(Middleware) = [] of Middleware) : Nil
    assistant.routes(middleware).each { |route| @router.add(route) }
  end
end
