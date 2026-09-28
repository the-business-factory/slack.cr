# The values that every listener and middleware receives. Each payload kind has
# its own context type, for example `ActionContext` for `block_actions`.
abstract struct Slack::App::Context
  def initialize(@environment : Environment)
  end

  # Web API client for the workspace or organization that sent the request.
  def client : Slack::Api::Client
    @environment.client
  end

  # Web API client for *grant* of the installation that sent the request, for
  # example `Slack::Auth::GrantKey.new(:user, user_id)` to act as that user.
  # Each call resolves the grant again. It raises when the authorizer has no
  # client for *grant*: `Auth::ContractError` for a missing installation grant,
  # `GrantUnavailable` in single-token mode.
  def client(grant : Slack::Auth::GrantKey) : Slack::Api::Client
    @environment.authorizer.authorize(@environment.payload, grant)
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
