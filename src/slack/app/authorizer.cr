# Produces the Web API client for one verified request. `App#dispatch` calls it
# after parsing and before routing. When it raises, no listener runs and the
# request gets `Outcome::Status::Unauthorized`.
#
# `Context#client(grant)` calls `#authorize(payload, grant)` from inside a
# listener, for example to act as the user who sent the request.
abstract class Slack::App::Authorizer
  abstract def authorize(payload : App::Payload) : Slack::Api::Client

  # Returns a client for *grant* of the installation that sent *payload*.
  abstract def authorize(payload : App::Payload, grant : Slack::Auth::GrantKey) : Slack::Api::Client
end
