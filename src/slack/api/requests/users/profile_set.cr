require "json"

module Slack::Api
  # Sets profile fields of a user. Without *user*, Slack changes the token's user.
  # See https://docs.slack.dev/reference/methods/users.profile.set.
  #
  # Set several fields with *profile*, or one field with *name* and *value*.
  # Slack accepts one form or the other, so each has its own constructor.
  #
  # ```
  # Slack::Api::UsersProfileSet.new(profile: {status_text: "Focus time", status_emoji: ":headphones:"})
  # Slack::Api::UsersProfileSet.new(name: "title", value: "Release manager")
  # ```
  #
  # The method needs a user token. Slack also limits updates to 10 per user per
  # minute and checks field names, value lengths, and admin permissions.
  struct UsersProfileSet < Request(Models::Users::ProfileResponse)
    include JsonBody

    # The documented maximum number of fields in one *profile*.
    MAX_FIELDS = 50

    @profile : Hash(String, JSON::Any)?

    getter name : String?
    getter value : String?
    getter user : String?

    # Copies *profile* as JSON values, so later changes to the argument have no effect.
    def initialize(*, profile : NamedTuple | Hash, @user : String? = nil)
      @profile = JSON.parse(profile.to_json).as_h
    end

    def initialize(*, name : String, value : String, @user : String? = nil)
      @name = name
      @value = value
    end

    # A deep copy of the profile fields, or nil for a *name* and *value* request.
    def profile : Hash(String, JSON::Any)?
      @profile.clone
    end

    def method_path : String
      "users.profile.set"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      profile = @profile
      return issues unless profile
      if profile.empty?
        issues << UI::ValidationIssue.new(
          "users_profile_set.profile.empty", "profile", "Profile must contain at least one field.")
      elsif profile.size > MAX_FIELDS
        issues << UI::ValidationIssue.new(
          "users_profile_set.profile.too_many_fields", "profile", "Profile must contain at most #{MAX_FIELDS} fields.")
      end
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        if profile = @profile
          json.field "profile", profile
        else
          json.field "name", @name
          json.field "value", @value
        end
        @user.try { |user| json.field "user", user }
      end
    end
  end
end
