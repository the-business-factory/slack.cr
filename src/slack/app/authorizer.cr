# Produces the Web API client for one verified request. `App#dispatch` calls it
# after parsing and before routing. When it raises, no listener runs and the
# request gets `Outcome::Status::Unauthorized`.
abstract class Slack::App::Authorizer
  abstract def authorize(payload : App::Payload) : Slack::Api::Client
end
