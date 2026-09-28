require "uri"

module Slack::Api
  # Reads the user groups of a workspace.
  # See https://docs.slack.dev/reference/methods/usergroups.list.
  struct UsergroupsList < Request(Models::Usergroups::UsergroupList)
    include FormBody

    getter? include_count : Bool
    getter? include_disabled : Bool
    getter? include_users : Bool
    getter team_id : String?

    def initialize(*, @include_count : Bool = false, @include_disabled : Bool = false,
                   @include_users : Bool = false, @team_id : String? = nil)
    end

    def method_path : String
      "usergroups.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "include_count", "true" if @include_count
      form.add "include_disabled", "true" if @include_disabled
      form.add "include_users", "true" if @include_users
      @team_id.try { |team_id| form.add "team_id", team_id }
      form
    end
  end
end
