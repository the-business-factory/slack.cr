require "uri"

module Slack::Api
  # Reads the profile of the signed-in user. Call it with the user token from
  # Sign in with Slack (`SignIn#access_token`), which has the `openid` scope.
  # See https://docs.slack.dev/reference/methods/openid.connect.userInfo.
  #
  # ```
  # client = Slack::Api::Client.new(token: sign_in.access_token)
  # client.call(Slack::Api::OpenIDConnectUserInfo.new).email
  # ```
  struct OpenIDConnectUserInfo < Request(Models::OpenID::UserInfo)
    include FormBody

    def method_path : String
      "openid.connect.userInfo"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    # The request has no fields; the client sends the token in the header.
    def form : URI::Params
      URI::Params.new
    end
  end
end
