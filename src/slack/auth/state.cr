require "./clock"
require "./errors"

module Slack::Auth
  enum AuthorizationPurpose
    Installation
    OIDC
  end

  struct AuthorizationAttempt
    getter state : Secret
    getter session_binding : Secret
    getter purpose : AuthorizationPurpose
    getter expires_at : Time
    getter redirect_uri : String
    getter nonce : Secret?

    def initialize(@state : Secret, @session_binding : Secret, @purpose : AuthorizationPurpose,
                   @expires_at : Time, @redirect_uri : String, @nonce : Secret? = nil)
      if @redirect_uri.empty? || (@purpose.oidc? && @nonce.nil?) || (@purpose.installation? && !@nonce.nil?)
        raise ContractError.new(ErrorCode::InvalidConfiguration)
      end
    end
  end

  abstract class StateStore
    # The caller generates cryptographically random state and an OIDC nonce if needed.
    # Insert a new attempt. On a collision, raise Conflict without replacing it.
    abstract def issue(attempt : AuthorizationAttempt) : Nil

    # Check state, session, purpose, and expiry, then delete the match atomically.
    # Use the store clock. Reject expires_at <= now.
    # On a mismatch, raise InvalidState without deleting the attempt.
    abstract def consume(state : Secret, session_binding : Secret, purpose : AuthorizationPurpose) : AuthorizationAttempt
  end
end
