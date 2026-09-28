require "uri"

module Slack::Api
  # Reads the presence of a user. Without *user*, Slack reads the token's user
  # and adds connection details. See https://docs.slack.dev/reference/methods/users.getPresence.
  struct UsersGetPresence < Request(Models::Users::Presence)
    include FormBody

    getter user : String?

    def initialize(*, @user : String? = nil)
    end

    def method_path : String
      "users.getPresence"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params.new
      @user.try { |user| form.add "user", user }
      form
    end
  end
end
