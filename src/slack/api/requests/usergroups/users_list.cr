require "uri"

module Slack::Api
  # Reads the member IDs of a user group.
  # See https://docs.slack.dev/reference/methods/usergroups.users.list.
  struct UsergroupsUsersList < Request(Models::Usergroups::UserIdList)
    include FormBody

    getter usergroup : String
    getter? include_disabled : Bool
    getter team_id : String?

    def initialize(@usergroup : String, *, @include_disabled : Bool = false, @team_id : String? = nil)
    end

    def method_path : String
      "usergroups.users.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      form = URI::Params{"usergroup" => @usergroup}
      form.add "include_disabled", "true" if @include_disabled
      @team_id.try { |team_id| form.add "team_id", team_id }
      form
    end
  end
end
