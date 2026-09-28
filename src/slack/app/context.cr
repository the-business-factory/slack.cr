# The values that every listener and middleware receives. Each payload kind has
# its own context type, for example `ActionContext` for `block_actions`.
abstract struct Slack::App::Context
  def initialize(@environment : Environment)
  end

  # Web API client for the workspace or organization that sent the request.
  def client : Slack::Api::Client
    @environment.client
  end

  def log : ::Log
    @environment.log
  end

  # Events API retry headers. Nil for requests that are not events.
  def delivery : Slack::Events::Delivery?
    @environment.delivery
  end

  # Values that middleware shares with later middleware and the listener for
  # this request only.
  def store : Hash(String, String)
    @environment.store
  end

  private def acknowledge(body : AckBody?) : Nil
    raise AlreadyAcknowledged.new unless @environment.ack.respond(Outcome.acknowledged(body))
  end
end
