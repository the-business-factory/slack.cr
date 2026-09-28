require "uri"

module Slack::Api
  # Disables a user group. Slack sets its `date_delete`.
  # See https://docs.slack.dev/reference/methods/usergroups.disable.
  struct UsergroupsDisable < Request(Models::Usergroups::UsergroupChange)
    include FormBody

    getter usergroup : String
    getter? include_count : Bool
    getter team_id : String?

    def initialize(@usergroup : String, *, @include_count : Bool = false, @team_id : String? = nil)
    end

    def method_path : String
      "usergroups.disable"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      form = URI::Params{"usergroup" => @usergroup}
      form.add "include_count", "true" if @include_count
      @team_id.try { |team_id| form.add "team_id", team_id }
      form
    end
  end
end
