require "uri"

module Slack::Api
  # Reads the profile of a user. Without *user*, Slack reads the token's user.
  # See https://docs.slack.dev/reference/methods/users.profile.get.
  #
  # Slack rate limits *include_labels* strongly; read labels from
  # `team.profile.get` through the generic call and cache them instead.
  struct UsersProfileGet < Request(Models::Users::ProfileResponse)
    include FormBody

    getter user : String?
    getter? include_labels : Bool

    def initialize(*, @user : String? = nil, @include_labels : Bool = false)
    end

    def method_path : String
      "users.profile.get"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def form : URI::Params
      form = URI::Params.new
      @user.try { |user| form.add "user", user }
      form.add "include_labels", "true" if @include_labels
      form
    end
  end
end
