require "uri"

module Slack::Api
  # Exchanges a Sign in with Slack code, or a refresh token, for a user token and
  # an ID token. See https://docs.slack.dev/reference/methods/openid.connect.token.
  #
  # Call it with a client that has no token. `Slack::OIDC::SignInHandler` sends
  # the code exchange and verifies the ID token; use this request directly for
  # the refresh grant:
  #
  # ```
  # client = Slack::Api::Client.new(token: nil)
  # token = client.call(Slack::Api::OpenIDConnectToken.refresh(
  #   client_id: "1234.5678", client_secret: ENV["SLACK_CLIENT_SECRET"], refresh_token: stored_refresh_token))
  # ```
  #
  # The client secret, the authorization code, and the refresh token are
  # `Auth::Secret` values, so `inspect` and `to_s` redact them.
  struct OpenIDConnectToken < Request(Models::OpenID::Token)
    include FormBody

    getter client_id : String
    getter client_secret : Auth::Secret
    # The authorization code. Nil for the refresh grant.
    getter code : Auth::Secret?
    # The redirect URI of the authorization request. Nil for the refresh grant.
    getter redirect_uri : String?
    # The refresh token. Nil for the authorization code grant.
    getter refresh_token : Auth::Secret?

    # The authorization code grant (`grant_type=authorization_code`).
    def initialize(*, @client_id : String, client_secret : String | Auth::Secret, code : String | Auth::Secret,
                   redirect_uri : String)
      @client_secret = OpenIDConnectToken.secret(client_secret)
      @code = OpenIDConnectToken.secret(code)
      @redirect_uri = redirect_uri
    end

    # The refresh token grant (`grant_type=refresh_token`). The library does not
    # store the refresh token; the application keeps the one Slack returns.
    def self.refresh(*, client_id : String, client_secret : String | Auth::Secret,
                     refresh_token : String | Auth::Secret) : self
      new(client_id, secret(client_secret), secret(refresh_token))
    end

    private def initialize(@client_id : String, @client_secret : Auth::Secret, refresh_token : Auth::Secret)
      @refresh_token = refresh_token
    end

    # :nodoc:
    def self.secret(value : String | Auth::Secret) : Auth::Secret
      value.is_a?(Auth::Secret) ? value : Auth::Secret.new(value)
    end

    def method_path : String
      "openid.connect.token"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      FieldChecks.blank_issue(issues, "openid_connect_token", "client_id", @client_id, "Client ID")
      FieldChecks.blank_issue(issues, "openid_connect_token", "client_secret", @client_secret.value, "Client secret")
      FieldChecks.blank_issue(issues, "openid_connect_token", "code", @code.try(&.value), "Code")
      FieldChecks.blank_issue(issues, "openid_connect_token", "redirect_uri", @redirect_uri, "Redirect URI")
      FieldChecks.blank_issue(issues, "openid_connect_token", "refresh_token", @refresh_token.try(&.value),
        "Refresh token")
      issues
    end

    def form : URI::Params
      if refresh_token = @refresh_token
        return URI::Params{"grant_type" => "refresh_token", "client_id" => @client_id,
                           "client_secret" => @client_secret.value, "refresh_token" => refresh_token.value}
      end

      URI::Params{"grant_type" => "authorization_code", "client_id" => @client_id,
                  "client_secret" => @client_secret.value, "code" => @code.try(&.value).to_s, "redirect_uri" => @redirect_uri.to_s}
    end
  end
end
