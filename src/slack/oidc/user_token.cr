require "../auth/errors"

module Slack::OIDC
  # The user token of a person who signed in with Slack. It has only the
  # scopes of the sign-in (`openid`, and `profile` and `email` when
  # requested), so it can call `openid.connect.userInfo` but not other
  # methods.
  #
  # With token rotation, `refresh_token` and `expires_at` are present. The
  # library does not store either; keep them where the application keeps
  # its sessions if it refreshes the token.
  struct UserToken
    getter access_token : Auth::Secret
    getter refresh_token : Auth::Secret?
    getter expires_at : Time?

    def initialize(@access_token : Auth::Secret, @refresh_token : Auth::Secret? = nil, @expires_at : Time? = nil)
    end

    def inspect(io : IO) : Nil
      io << "Slack::OIDC::UserToken([REDACTED])"
    end

    def to_s(io : IO) : Nil
      inspect(io)
    end
  end
end
