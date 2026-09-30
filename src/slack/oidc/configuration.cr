require "uri"
require "../auth/errors"

module Slack::OIDC
  # The Sign in with Slack settings of one app. `SignInHandler` validates it.
  #
  # *redirect_uri* must be a redirect URL of the app in its Slack
  # configuration. Change *authorization_uri*, *jwks_uri*, and *issuer* only
  # for tests; the defaults are Slack's published values.
  record Configuration,
    client_id : String,
    client_secret : Auth::Secret,
    redirect_uri : URI,
    authorization_uri : URI = URI.parse("https://slack.com/openid/connect/authorize"),
    jwks_uri : URI = URI.parse("https://slack.com/openid/connect/keys"),
    issuer : String = "https://slack.com"
end
