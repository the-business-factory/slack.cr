require "uri"

module Slack::Api
  # Finds the user with an email address.
  # See https://docs.slack.dev/reference/methods/users.lookupByEmail.
  #
  # Slack returns `users_not_found` as `Api::Error#code` when no user has the address.
  struct UsersLookupByEmail < Request(Models::Users::UserResponse)
    include FormBody

    getter email : String

    def initialize(@email : String)
    end

    def method_path : String
      "users.lookupByEmail"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params{"email" => @email}
    end
  end
end
