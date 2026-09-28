require "uri"

module Slack::Api
  # Replaces the members of a user group with *users*.
  # See https://docs.slack.dev/reference/methods/usergroups.users.update.
  #
  # Slack cannot remove every member, so *users* must not be empty. Disable the
  # group with `UsergroupsDisable` instead.
  struct UsergroupsUsersUpdate < Request(Models::Usergroups::UsergroupResponse)
    include FormBody

    @users : Array(String)
    @additional_channels : Array(String)?

    getter usergroup : String
    getter? include_count : Bool
    getter team_id : String?
    getter? is_shared : Bool

    def initialize(@usergroup : String, users : Enumerable(String), *, @include_count : Bool = false,
                   @team_id : String? = nil, additional_channels : Enumerable(String)? = nil,
                   @is_shared : Bool = false)
      # Copy once: Array#to_a returns the caller's array itself.
      @users = users.map(&.itself)
      @additional_channels = additional_channels.try(&.map(&.itself))
    end

    def users : Array(String)
      @users.dup
    end

    def additional_channels : Array(String)?
      @additional_channels.dup
    end

    def method_path : String
      "usergroups.users.update"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @users.empty?
        issues << UI::ValidationIssue.new(
          "usergroups_users_update.users.empty", "users", "Supply at least one user ID.")
      end
      if (ids = @additional_channels) && ids.empty?
        issues << UI::ValidationIssue.new("usergroups.additional_channels.empty", "additional_channels",
          "Supply at least one channel ID, or omit additional_channels.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"usergroup" => @usergroup, "users" => @users.join(',')}
      form.add "include_count", "true" if @include_count
      @team_id.try { |team_id| form.add "team_id", team_id }
      @additional_channels.try { |ids| form.add "additional_channels", ids.join(',') }
      form.add "is_shared", "true" if @is_shared
      form
    end
  end
end
