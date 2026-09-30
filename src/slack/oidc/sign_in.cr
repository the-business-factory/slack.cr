require "./identity"
require "./user_token"

module Slack::OIDC
  # The result of one Sign in with Slack callback: the verified identity and
  # the user token. The application decides what a sign-in allows, for
  # example which workspaces (`identity.team_id`) and whether an unverified
  # email is enough, and it creates the session.
  struct SignIn
    getter identity : Identity
    getter token : UserToken

    def initialize(@identity : Identity, @token : UserToken)
    end

    delegate access_token, refresh_token, expires_at, to: @token

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::SignIn([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end
