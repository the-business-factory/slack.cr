module Slack::OIDC
  # The verified identity of a person who signed in with Slack. Only
  # `IDTokenVerifier` makes one, after every check passed.
  #
  # `email` and `email_verified` are present with the `email` scope; the
  # names and `locale` with the `profile` scope. `inspect` and `to_s` redact
  # every field, because the fields identify a person.
  struct Identity
    # The `sub` claim.
    getter subject : String
    # The Slack user ID (`https://slack.com/user_id`).
    getter user_id : String
    # The Slack workspace ID (`https://slack.com/team_id`).
    getter team_id : String
    getter email : String?
    getter? email_verified : Bool?
    getter name : String?
    getter given_name : String?
    getter family_name : String?
    getter locale : String?
    # When the person authenticated (`auth_time`), if Slack sent it.
    getter authenticated_at : Time?
    # When the ID token expires (`exp`).
    getter expires_at : Time

    protected def initialize(@subject : String, @user_id : String, @team_id : String, @expires_at : Time, *,
                             @email : String? = nil, @email_verified : Bool? = nil, @name : String? = nil,
                             @given_name : String? = nil, @family_name : String? = nil,
                             @locale : String? = nil, @authenticated_at : Time? = nil)
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::Identity([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end
