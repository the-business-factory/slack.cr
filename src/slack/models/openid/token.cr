require "json"

module Slack::Models::OpenID
  # The `openid.connect.token` result. The tokens are `Auth::Secret` values, so
  # `inspect` and `to_s` redact them. The ID token is not verified here: use
  # `Slack::OIDC::SignInHandler`, which verifies it before it gives any claim.
  struct Token
    include JSON::Serializable
    include Slack::Api::Envelope

    # A user token (`xoxp-`) with the granted `openid` scopes.
    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter access_token : Slack::Auth::Secret

    getter token_type : String

    # The signed ID token. It contains the email address and names, so it is a
    # secret too. The code exchange returns one; a refresh response may not
    # (OpenID Connect Core 1.0, section 12.2).
    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter id_token : Slack::Auth::Secret?

    # Present only when the app uses token rotation.
    @[JSON::Field(converter: Slack::Interactions::SecretConverter, ignore_serialize: true)]
    getter refresh_token : Slack::Auth::Secret?

    # Seconds until the access token expires. Present only with token rotation.
    getter expires_in : Int32?
  end
end
