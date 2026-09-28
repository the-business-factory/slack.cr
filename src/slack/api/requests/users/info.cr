require "uri"

module Slack::Api
  # Reads one user. See https://docs.slack.dev/reference/methods/users.info.
  struct UsersInfo < Request(Models::Users::UserResponse)
    include FormBody

    getter user : String
    getter? include_locale : Bool

    def initialize(@user : String, *, @include_locale : Bool = false)
    end

    def method_path : String
      "users.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def form : URI::Params
      form = URI::Params{"user" => @user}
      form.add "include_locale", "true" if @include_locale
      form
    end
  end
end
